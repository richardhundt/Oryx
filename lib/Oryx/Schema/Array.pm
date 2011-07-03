package Oryx::Schema::Array;

use strict;
use warnings;

use Oryx::Schema;
use Oryx::Util qw/class2fkey class2table class2field inflector/;

use base qw/Oryx::Schema::Assoc/;

sub new {
    my ( $class, $type, %opts ) = @_;

    my $self = bless {
        type   => $type,
        class  => $opts{class},
        compos => $opts{compos},
    }, $class;

    $self->type->{ compos } = $self->{ compos };
    return $self;
}

sub type  { shift->{type}  }

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    $self->{name} ||= class2field( $self->{class} );
    $self->{name};
}

sub bind {
    my ( $self, $oid ) = @_;
    if ( ref( $oid ) eq 'HASH' ) {
        $oid = $oid->{id};
    } elsif ( UNIVERSAL::isa( $oid, 'Oryx::Object' ) ) {
        $oid = $oid->oid;
    }
    $self->columns();
    Oryx::Schema::Array::Binding->new( oid => $oid, meta => $self );
}

sub key {
    my ( $self ) = @_;
    $self->{key} ||= class2fkey( $self->class );
}

sub key_type { 'integer' }

# `idx_field' is our array idx, and describes the column used for storing it.
sub idx_field {
    my $self = shift;
    $self->{idx_field} ||= Oryx::Schema->integer( name => 'array_idx' );
}

# `val_field' is either other_class_id or a flat value of any type
sub val_field {
    my $self = shift;
    $self->{val_field} ||= do {
        my $field;
        if ( $self->type->isa( 'Oryx::Schema::Field' ) ) {
            $field = $self->type;
            $field->name( inflector->singular( $self->name ) );
        } else {
            my $key_type = $self->type->key_type;
            $field = Oryx::Schema->$key_type( name => $self->type->key );
        }
        $self->type->{compos} = $self->{compos};
        $field;
    };
}

# try to make the naming intuitive using the singular of the class name
# and only adding the assoc. name if it's different from the pluralised
# form of the type name (where type may be any valid schema construct,
# field or assoc, etc.) eg:  user_notes OR user_published_articles
sub table {
    my $self = shift;
    $self->{table} ||= do {
        my $type  = $self->type;
        my $table = class2field( $self->class ).'_';
        if ( $type->name && $self->name ne inflector->plural($type->name) ) {
            $table .= $self->name.'_'.inflector->plural( $type->name );
        } else {
            $table .= $self->name; 
        }
        $table;
    }
}

sub primary {
    my $self = shift;
    $self->{primary} ||= [ $self->key, $self->idx_field->name ];
    wantarray ? @{ $self->{primary} } : $self->{primary};
}

sub columns {
    my $self = shift;
    $self->{columns} ||= [
        $self->key, $self->idx_field->name, $self->val_field->name
    ];
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my $self = shift;
    $self->{column_types} ||= [
        $self->key_type, $self->idx_field->type, $self->val_field->type
    ];
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my $self = shift;
    $self->{column_sizes} ||= [
        undef, $self->idx_field->size, undef
    ];
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

sub delete { }

package Oryx::Schema::Array::Binding;

use strict;
use warnings;

use UNIVERSAL qw/can/;

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

sub load {
    my ( $self ) = @_;
    my $meta = $self->meta;

    my $query = $meta->query;
    my $table = $meta->table;

    my $key = $meta->key;
    my $oid = $self->oid;

    my @colms = $meta->columns;
    my %where = ( $key => $oid );
    my ( $stmt, @bind ) = $query->select( $table, \@colms, \%where );

    my $list = $meta->storage->list( $stmt, undef, @bind );
    $self->init( $list );
}

sub init {
    my ( $self, $list ) = @_;
    my $meta = $self->meta;

    my $kname = $meta->idx_field->name;
    my $vname = $meta->val_field->name;
    my $vtype = $meta->type;

    my @array;
    foreach my $rec ( @$list ) {
        $array[ $rec->{ $kname } ] = $vtype->bind( $rec->{ $vname } );
    }

    return \@array;
}

sub save {
    my ( $self, $object ) = @_;
    $self->{oid} = $object->oid;
    if ( my $cache = CORE::delete $self->{ cache } ) {
        my $meta = $self->meta;
        my $list = $self->load;
        my %seen = ( );

        my $x = 0;
        foreach my $item ( @$cache ) {
            $item->save() if can( $item, 'save' );
            $seen{ $item }++;
            if ( exists $list->[ $x ] ) {
                unless ( $item eq $list->[$x] ) {
                    $self->update_entry( $x, $item );
                }
            } else {
                $self->insert_entry( $x, $item );
            }
            $x++;
        }

        for ( 0 .. $#$list ) {
            $self->delete_entry( $_ ) if ( $_ > $#$cache );
            unless ( $seen{ $list->[$_] } ) {
                if ( $meta->{ compos } and can( $list->[$_], 'delete' ) ) {
                    $list->[$_]->delete( $self );
                }
            }
        }
    }
}

sub fetch {
    my $self = shift;
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

sub push {
    my $self = CORE::shift(@_);
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

sub insert_entry {
    my ( $self, $key, $val ) = @_;
    my $meta = $self->meta;
    my $query = $meta->query;
    my $table = $meta->table;

    my @cols = $meta->columns;
    my %data = ( );
    @data{ @cols } = ( $self->oid, $key, $val );

    my ( $stmt, @bind ) = $query->insert( $table, \%data );
    $meta->storage->exec( $stmt, undef, @bind );
}

sub update_entry {
    my ( $self, $key, $val ) = @_;
    my $meta = $self->meta;

    my $query = $meta->query;
    my $table = $meta->table;

    my $kname = $meta->idx_field->name;
    my $vname = $meta->val_field->name;

    my $fkey  = $meta->key;
    my %data  = ( $vname => $val );
    my %where = (
        $fkey  => $self->oid,
        $kname => $key,
    );

    my ( $stmt, @bind ) = $query->update( $table, \%data, \%where );
    $meta->storage->exec( $stmt, undef, @bind );
}

sub delete_entry {
    my ( $self, $key ) = @_;
    my $meta = $self->meta;
    my $query = $meta->query;
    my $table = $meta->table;
    my $kname = $meta->idx_field->name;

    my $fkey = $meta->key;
    my %where = (
        $fkey  => $self->oid,
        $kname => $key,
    );
    my ( $stmt, @bind ) = $query->delete( $table, \%where );
    $meta->storage->exec( $stmt, undef, @bind );
}

1;
