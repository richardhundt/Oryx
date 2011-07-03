package Oryx::Schema::IntrArray;

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
    Oryx::Schema::IntrArray::Binding->new( oid => $oid, meta => $self );
}

sub key {
    my ( $self ) = @_;
    $self->{key} ||= class2fkey( $self->class );
}

sub key_type { 'integer' }

# `idx_field' is our array idx, and describes the column used for storing it.
sub idx_field {
    my $self = shift;
    $self->{idx_field} ||= Oryx::Schema->integer(
        name => class2field( $self->class ).'_'.$self->name.'_idx',
    );
}


# We use the other classes table and add an extra column to that so that
# we can reference this table from there - classic one-to-many relation.
sub table { shift->other->meta->table }

sub columns {
    my ( $self ) = @_;
    $self->{columns} ||= do {
        # definitely intrusive ;-)

        my $other = $self->other->meta;
        unless ( grep { $_ eq $self->key } @{ $other->columns } ) {
            push @{ $other->columns }, $self->key;
        }

        push @{ $other->columns }, $self->idx_field->name;
        unless ( grep { $_ eq $self->key_type } @{ $other->column_types } ) {
            push @{ $other->column_types }, $self->key_type;
        }

        push @{ $other->column_types }, $self->idx_field->type;
        $other->valid->{ $self->key } = $self->key_type;
        $other->valid->{ $self->idx_field->name } = $self->idx_field->type;

        [ $self->key, $self->idx_field->name ];
    };
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my ( $self ) = @_;
    $self->{column_types} ||= [ $self->key_type, $self->idx_field->type ];
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my ( $self ) = @_;
    $self->{column_sizes} ||= [ undef, undef ];
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

sub delete { }


package Oryx::Schema::IntrArray::Binding;

use strict;

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

sub oid  { $_[0]{oid}  }
sub meta { $_[0]{meta} }

sub fetch {
    my ( $self ) = @_;
    $self->{ cache } ||= $self->load;
}

sub store {
    my $self = CORE::shift;
    if ( @_ == 1 and ref $_[0] eq 'ARRAY' ) {
        $self->{ cache } = CORE::shift;
    } else {
        $self->{ cache } = [ @_ ];
    }
}

sub load {
    my ( $self ) = @_;
    return [ ] unless $self->oid;
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
    my $kname = $meta->idx_field->name;
    my @array;
    foreach my $rec ( @$list ) {
        $array[ $rec->{ $kname } ] = $other->new( $rec );
    }
    \@array;
}

sub save {
    my ( $self, $object ) = @_;
    $self->{oid} = $object->oid;
    if ( my $cache = CORE::delete $self->{ cache } ) {
        my $list = $self->load;
        my $meta = $self->meta;
        my %seen = ( );

        my $key = $meta->key;
        my $idx = $meta->idx_field->name;
        my $x = 0;
        no warnings 'uninitialized';
        for my $item ( @$cache ) {
            $seen{ $item }++;
            $item->$key( $self->{ oid } );
            $item->$idx( $x );
            $item->save();
            $x++;
        }

        for ( 0 .. $#$list ) {
            if ( not $seen{ $list->[$_] } or $_ > $#$cache ) {
                if ( $meta->{ compos } ) {
                    $list->[$_]->delete( $self );
                } else {
                    $list->[$_]->$key( undef );
                    $list->[$_]->$idx( undef );
                    $list->[$_]->save();
                }
            }
        }
    }
    return $self;
}

sub delete {
    my ( $self, $object ) = @_;
    my $meta = $self->meta;
    my $key = $meta->key;
    my $idx = $meta->idx_field->name;
    if ( $meta->{ compos } ) {
        for my $item ( @{ $self->fetch } ) {
            $item->delete() if defined $item->oid;
        }
    } else {
        for my $item ( @{ $self->fetch } ) {
            $item->$key( undef );
            $item->$idx( undef );
            $item->save();
        }
    }
    $self->save();
}

sub push {
    my $self = CORE::shift;
    CORE::push( @{ $self->fetch }, @_ );
}
sub pop {
    my $self = CORE::shift;
    CORE::pop( @{ $self->fetch } );
}
sub shift {
    my $self = CORE::shift;
    CORE::shift( @{ $self->fetch } );
}
sub unshift {
    my $self = CORE::shift;
    CORE::unshift( @{ $self->fetch }, @_ );
}
sub splice {
    my $self = CORE::shift;
    CORE::splice( @{ $self->fetch }, @_ );
}

#sub DESTROY { $_[0]->save() }

1;
