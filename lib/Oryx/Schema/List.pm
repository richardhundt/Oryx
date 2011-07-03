package Oryx::Schema::List;

use strict;
use warnings;

use Oryx::Util qw/class2fkey class2table class2field/;

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
    if ( ref( $oid ) eq 'HASH' ) {
        $oid = $oid->{ id };
    } elsif ( UNIVERSAL::isa( $oid, 'Oryx::Object' ) ) {
        $oid = $oid->oid;
    }
    $self->columns();
    Oryx::Schema::List::Binding->new( oid => $oid, meta => $self );
}

sub key {
    my ( $self ) = @_;
    $self->{key} ||= class2fkey( $self->class );
}

sub key_type { 'integer' }

# We use the other classes table and add an extra column to that so that
# we can reference this table from there - classic one-to-many relation.
sub table { shift->other->meta->table }

sub columns {
    my ( $self ) = @_;
    $self->{columns} ||= do {
        $self->{columns} = [ ]; # prevent deep recursion

        my $other = $self->other->meta;
        unless ( grep { $_ eq $self->key } @{ $other->columns } ) {
            push @{ $other->columns }, $self->key;
        }
        unless ( grep { $_ eq $self->key_type } @{ $other->column_types } ) {
            push @{ $other->column_types }, $self->key_type;
        }
        $other->valid->{ $self->key } = $self->key_type;
        [ $self->key ];
    };
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my ( $self ) = @_;
    $self->{column_types} ||= [ $self->key_type ];
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my ( $self ) = @_;
    $self->{column_sizes} ||= [ undef ];
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

sub delete { }


package Oryx::Schema::List::Binding;

use strict;
use warnings;

use overload
    '@{}' => \&fetch,
    fallback => 1;

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
    $self->{ cache } ||= $self->load;
}

sub store {
    my $self = shift;
    if ( @_ == 1 and ref $_[0] eq 'ARRAY' ) {
        $self->{ cache } = shift;
    } else {
        $self->{ cache } = [ @_ ];
    }
}

sub insert {
    my ( $self, $item ) = @_;
    push @{ $self->fetch }, $item;
}

sub remove {
    my ( $self, $item ) = @_;
    my ( $found ) = grep { $_ == $item } @{ $self->fetch };
    $found->delete() if $found;
}

*retrieve = \&contains;
sub contains {
    my ( $self, $item ) = @_;
    my ( $found ) = grep { $_->oid == $item->oid } @{ $self->fetch };
    return $found;
}

sub load {
    my $self = shift;
    return [ ] unless $self->oid;
    my $meta = $self->meta;

    my $query = $meta->query;
    my $table = $meta->table;

    my $key = $meta->key;
    my $oid = $self->oid;

    my @colms = $meta->other->meta->columns;
    my %where = ( $key => $oid );
    my ( $stmt, @bind ) = $query->select( $table, \@colms, \%where );
    my $list = $meta->storage->list( $stmt, undef, @bind );
    $self->init( $list );
}

sub init {
    my ( $self, $list ) = @_;
    my $other = $self->meta->other;
    my @items;
    for my $item ( @$list ) {
        push @items, $other->new( $item );
    }
    \@items;
}

sub save {
    my ( $self, $object ) = @_;
    $self->{oid} = $object->oid;
    if ( my $list = CORE::delete $self->{ cache } ) {
        my $key = $self->meta->key;
        for my $item ( @$list ) {
            $item->$key( $self->{ oid } );
            $item->save;
        }
    }
    return $self;
}

sub delete {
    my ( $self, $object ) = @_;
    if ( $self->meta->{ compos } ) {
        for my $item ( @{ $self->fetch } ) {
            $item->delete() if defined $item->oid;
        }
    }
    $self->save();
}

1;
