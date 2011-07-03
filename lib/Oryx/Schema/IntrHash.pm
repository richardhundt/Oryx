package Oryx::Schema::IntrHash;

use strict;
use warnings;

use Oryx::Schema;
use Oryx::Util qw/class2fkey class2table class2field/;

use base qw/Oryx::Schema::Assoc/;

sub new {
    my ( $class, $type, %opts ) = @_;
    my $self = bless {
        other  => $type,
        compos => $opts{compos},
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
    Oryx::Schema::IntrHash::Binding->new( oid => $oid, meta => $self );
}

sub key {
    my ( $self ) = @_;
    $self->{key} ||= class2fkey( $self->class );
}

sub key_type { 'integer' }

# `key_field' is our hash key, and describes the column used for storing it.
sub key_field {
    my $self = shift;
    $self->{key_field} ||= Oryx::Schema->string(
        name => class2field( $self->class ).'_'.$self->name.'_key',
    );
}


# We use the other classes table and add an extra column to that so that
# we can reference this table from there - classic one-to-many relation.
sub table { shift->other->meta->table }

sub columns {
    my ( $self ) = @_;
    $self->{columns} ||= do {
        # prevent deep recursion
        $self->{columns} = [ ];

        my $other = $self->other->meta;
        unless ( grep { $_ eq $self->key } @{ $other->columns } ) {
            push @{ $other->columns }, $self->key;
        }
        push @{ $other->columns }, $self->key_field->name;
        unless ( grep { $_ eq $self->key_type } @{ $other->column_types } ) {
            push @{ $other->column_types }, $self->key_type;
        }
        push @{ $other->column_types }, $self->key_field->type;
        $other->valid->{ $self->key } = $self->key_type;
        $other->valid->{ $self->key_field->name } = $self->key_field->type;

        [ $self->key, $self->key_field->name ];
    };
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my ( $self ) = @_;
    $self->{column_types} ||= [ $self->key_type, $self->key_field->type ];
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my ( $self ) = @_;
    $self->{column_sizes} ||= [ undef, 255 ];
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

sub delete { }


package Oryx::Schema::IntrHash::Binding;

use strict;
use warnings;

use overload
    '%{}' => \&fetch,
    fallback => 1;

sub OID   () { 0 }
sub META  () { 1 }
sub CACHE () { 2 }

sub new {
    my ( $class, %args ) = @_;

    my $self = bless [ 
        $args{oid},
        $args{meta},
    ], $class;

    return $self;
}

sub oid  { $_[0][OID]  }
sub meta { $_[0][META] }

sub fetch {
    my ( $self ) = @_;
    $self->[ CACHE ] ||= $self->load;
}

sub store {
    my $self = shift;
    if ( @_ == 1 and ref $_[0] eq 'HASH' ) {
        $self->[ CACHE ] = shift;
    } else {
        $self->[ CACHE ] = { @_ };
    }
}

sub load {
    my ( $self ) = @_;
    return { } unless $self->oid;
    my $meta = $self->meta;

    my $query = $meta->query;
    my $table = $meta->table;

    my $key = $meta->key;
    my $oid = $self->oid;

    my @colms = ( $meta->other->meta->columns );
    my %where = ( $key => $oid );
    my ( $stmt, @bind ) = $query->select( $table, \@colms, \%where );
    my $list = $meta->storage->list( $stmt, undef, @bind );
    $self->init( $list );
}

sub init {
    my ( $self, $list ) = @_;
    my $meta = $self->meta;

    my $other = $meta->other;
    my $kname = $meta->key_field->name;

    my %hash;
    foreach my $rec ( @$list ) {
        $hash{ $rec->{ $kname } } = $other->new( $rec );
    }

    \%hash;
}

sub save {
    my ( $self, $object ) = @_;
    $self->[ OID ] = $object->oid;
    if ( my $cache = delete $self->[ CACHE ] ) {

        my $meta = $self->meta;
        my $hash = $self->load;
        my %seen = ( );

        my $pkey = $meta->key;
        my $hkey = $meta->key_field->name;

        while ( my ( $k, $v ) = each %$cache ) {
            $seen{ $k }++;
            $v->$pkey( $self->[ OID ] );
            $v->$hkey( $k );
            $v->save();
        }

        for ( keys %$hash ) {
            if ( not $seen{ $hash->{$_} } or $_ > $#$cache ) {
                if ( $meta->{ compos } ) {
                    $hash->{$_}->delete( $self );
                } else {
                    $hash->{$_}->$pkey( undef );
                    $hash->{$_}->$hkey( undef );
                    $hash->{$_}->save();
                }
            }
        }
    }
    return $self;
}

sub delete {
    my ( $self, $object ) = @_;
    my $meta = $self->meta;
    my $pkey = $meta->key;
    my $hkey = $meta->key_field->name;
    if ( $meta->{ compos } ) {
        for my $item ( values %{ $self->fetch } ) {
            $item->delete() if defined $item->oid;
        }
    } else {
        for my $item ( values %{ $self->fetch } ) {
            $item->$pkey( undef );
            $item->$hkey( undef );
            $item->save();
        }
    }
    $self->save();
}

# TODO: validate!
sub set {
    my ( $self, $key, $val ) = @_;
    $self->fetch->{ $key } = $val;
}

sub get {
    my ( $self, $key ) = @_;
    $self->fetch->{ $key };
}


1;
