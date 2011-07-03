package Oryx::Schema::Ref;

use strict;
use warnings;

use Oryx::Util qw/class2fkey class2table class2field/;
use Carp qw/carp/;

use base qw/Oryx::Schema::Assoc/;

sub new {
    my ( $class, $type, %opts ) = @_;
    my $self = bless {
        other  => $type,
        compos => $opts{compos},
        key    => $opts{key},
    }, $class;
    return $self;
}

sub other { shift->{other} }

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    $self->{name} ||= class2field( $self->{other} );
    $self->{name};
}

sub bind {
    my ( $self, $oid ) = @_;
    my $fkey = $self->key;
    if ( ref( $oid ) eq 'HASH' ) {
        $oid = $oid->{ $fkey };
    } elsif ( UNIVERSAL::isa( $oid, 'Oryx::Object' ) ) {
        $oid = $oid->$fkey;
    }
    Oryx::Schema::Ref::Binding->new( oid => $oid, meta => $self );
}

sub key {
    my ( $self ) = @_;
    $self->{key} ||= do {
        my $key;
        if ( $self->name eq class2field( $self->{other} ) ) {
            $key = class2fkey( $self->{other} );
        } else {
            $key = $self->name.'_'.class2fkey( $self->{other} );
        }
        $key;
    };
}

sub key_type { 'integer' }

sub table { shift->class->meta->table }

sub columns {
    my $self = shift;
    $self->{columns} ||= [ $self->key ];
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my $self = shift;
    $self->{column_types} ||= [ $self->key_type ];
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my $self = shift;
    $self->{column_sizes} ||= [ undef ];    
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

sub delete { }

package Oryx::Schema::Ref::Binding;

use strict;
use warnings;

use overload '0+' => \&oid, fallback => 1;

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    my ( $name ) = ( $AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';
    return $self->fetch->$name( @_ ) if $self->fetch;
}

sub new {
    my ( $class, %args ) = @_;

    my $self = bless { 
        oid  => $args{oid},
        meta => $args{meta},
    }, $class;
    
    return $self;
}

sub oid  { shift->{oid}  }
sub meta { shift->{meta} }

sub fetch {
    my ( $self ) = @_;
    return $self->{ changed } if $self->{ changed };
    return undef unless $self->{ oid };
    $self->{ changed } = $self->load;
}

sub store {
    my ( $self, $value ) = @_;
    $self->{ changed } = $value;
    if ( ref $value ) {
        $value->save() unless defined $value->oid;
        $self->{ oid } = $value->oid;
    } else {
        $self->{ oid } = $value;
    }
}

sub load {
    my $self = shift;
    $self->meta->other->fetch( $self->{ oid } );
}

sub save {
    my ( $self, $object ) = @_;
    if ( $self->{ changed } and defined $object ) {
        my $ref = delete $self->{ changed };
        my $key = $self->meta->key;
        $object->$key( $self->{ oid } );
        $ref->save if $self->meta->{ compos };
    } else {
        $self->fetch->save() if $self->fetch;
    }
    return $self;
}

sub delete {
    my ( $self, $object ) = @_;
    if ( $self->meta->{ compos } ) {
        if ( my $ref = $self->fetch ) {
            $ref->delete();
        }
    }
}

1;
