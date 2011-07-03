package Oryx::Schema::Hash;

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
    Oryx::Schema::Hash::Binding->new( oid => $oid, meta => $self );
}

# The `key' and `key_type' are used by Oryx::Object::{load,save} and 
# have nothing to do with hash keys which this class also uses.
sub key {
    my ( $self ) = @_;
    $self->{key} ||= class2fkey( $self->class );
}

sub key_type { 'integer' }

# `key_field' is our hash key, and describes the column used for storing it.
sub key_field {
    my $self = shift;
    $self->{key_field} ||= Oryx::Schema->string(
        name => 'hash_key', size => '255',
    );
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
    $self->{primary} ||= [ $self->key, $self->key_field->name ];
    wantarray ? @{ $self->{primary} } : $self->{primary};
}

sub columns {
    my $self = shift;
    $self->{columns} ||= [
        $self->key, $self->key_field->name, $self->val_field->name
    ];
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my $self = shift;
    $self->{column_types} ||= [
        $self->key_type, $self->key_field->type, $self->val_field->type
    ];
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my $self = shift;
    $self->{column_sizes} ||= [
        undef, $self->key_field->size, $self->val_field->size
    ];
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

sub delete { }


package Oryx::Schema::Hash::Binding;

use strict;
use warnings;

use overload
    '%{}' => \&fetch,
    fallback => 1;

use UNIVERSAL qw/can/;

sub OID   () { 0 }
sub META  () { 1 }
sub CACHE () { 2 }

sub new {
    my ( $class, %args ) = @_;

    # this has to be a bless ARRAY ref because we're overloading %{}
    # and you get deep recursion issues with \&fetch otherwise if
    # trying to access internal props
    my $self = bless [
        $args{oid},
        $args{meta},
    ], $class;

    return $self;
}

sub oid  { shift->[OID]  }
sub meta { shift->[META] }

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

    my $kname = $meta->key_field->name;
    my $vname = $meta->val_field->name;
    my $vtype = $meta->type;

    my %hash;
    foreach my $rec ( @$list ) {
        $hash{ $rec->{ $kname } } = $vtype->bind( $rec->{ $vname } );
    }

    return \%hash;
}

sub save {
    my ( $self, $object ) = @_;
    $self->[ OID ] = $object->oid;
    if ( my $cache = delete $self->[ CACHE ] ) {

        my $meta = $self->meta;
        my $hash = $self->load;
        my %seen = ( );

        my $vname = $meta->val_field->name;
        my $kname = $meta->key_field->name;

        while ( my ( $k, $v ) = each %$cache ) {
            $seen{ $k }++;
            $v->save if can( $v, 'save' );
            if ( exists $hash->{ $k } ) {
                $self->update_entry( $k, $v ) unless $v eq $hash->{ $k };
            } else {
                # insert a record in our link table
                $self->insert_entry( $k, $v );
            }
        }

        for ( keys %$hash ) {
            unless ( $seen{ $_ } ) {
                $self->delete_entry( $_ );
                if ( $meta->{ compos } and can( $hash->{$_}, 'delete' ) ) {
                    $hash->{$_}->delete();
                }
            }
        }
    }
}

sub fetch {
    my $self = shift;
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

# TODO: validate!
sub set {
    my ( $self, $key, $val ) = @_;
    $self->fetch->{ $key } = $val;
}

sub get {
    my ( $self, $key ) = @_;
    $self->fetch->{ $key };
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

    my $kname = $meta->key_field->name;
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
    my $kname = $meta->key_field->name;

    my $fkey = $meta->key;
    my %where = (
        $fkey  => $self->oid,
        $kname => $key,
    );
    my ( $stmt, @bind ) = $query->delete( $table, \%where );
    $meta->storage->exec( $stmt, undef, @bind );
}

1;
