package Oryx::Schema;

use strict;
use warnings;

use Carp qw/croak/;
use Storable ();

use Oryx::Util qw/class2file/;
use Oryx::Object;
use Oryx::Stub;

use Oryx::Schema::Ref;
use Oryx::Schema::List;
use Oryx::Schema::Hash;
use Oryx::Schema::Array;
use Oryx::Schema::IntrHash;
use Oryx::Schema::IntrArray;

use Oryx::Schema::Meta;

use Oryx::Schema::Field::Oid;
use Oryx::Schema::Field::String;
use Oryx::Schema::Field::Integer;
use Oryx::Schema::Field::Boolean;
use Oryx::Schema::Field::Binary;
use Oryx::Schema::Field::Float;
use Oryx::Schema::Field::Text;
use Oryx::Schema::Field::Email;
use Oryx::Schema::Field::Url;
use Oryx::Schema::Field::Password;
use Oryx::Schema::Field::Enum;
use Oryx::Schema::Field::File;
use Oryx::Schema::Field::Date;
use Oryx::Schema::Field::Time;
use Oryx::Schema::Field::DateTime;
use Oryx::Schema::Field::Range;
use Oryx::Schema::Field::Complex;

use base qw/Class::Data::Inheritable/;

__PACKAGE__->mk_classdata( $_ => { } ) for qw/classes descriptors deployed/;
__PACKAGE__->mk_classdata( storage => undef );

sub define {
    my ( $pkg, %specs ) = @_;

    foreach my $name ( keys %specs ) {
        my $spec = $specs{ $name };
        my $meta = $pkg->class( $name );
        $meta->base( $spec->{base} ) if $spec->{base};
        $meta->abstract( $spec->{abstract} ) if $spec->{abstract};

        $spec->{fields} ||= [ ];
        my @fields = @{ $spec->{fields} };
        while ( my ( $field, $value ) = splice ( @fields, 0, 2 ) ) {
            $meta->field( $field, $pkg->value( $value ) );
        }

        $spec->{assocs} ||= [ ];
        my @assocs = @{ $spec->{assocs} };
        while ( my ( $assoc, $value ) = splice ( @assocs, 0, 2 ) ) {
            $meta->assoc( $assoc, $pkg->value( $value ) );
        }

        $pkg->descriptors->{ $name } = $spec;
    }
}

sub value {
    my ( $pkg, $spec ) = @_;
    my ( $type, @args ) = @$spec;
    if ( ref $args[0] eq 'ARRAY' ) {
        return $pkg->$type( $pkg->value( $args[0] ) );
    }
    return $pkg->$type( @args );
}

sub class {
    my ( $self, $name, $base ) = @_;
    $base ||= 'Oryx::Object';
    $self->classes->{ $name } ||= do {
        my $meta = Oryx::Schema::Meta->new(
            name   => $name,
            schema => $self,
        );

        eval "require $name";
        my $file = class2file( $name );
        die $@ if ( $@ and exists $INC{$file} );
        $INC{$file} = $INC{'Oryx/Stub.pm'};

        no strict 'refs';
        *{ $name.'::meta' } = sub { $meta };

        unless ( UNIVERSAL::isa( $name, $base ) ) {
            push @{ $name.'::ISA' }, $base;
        }
        $meta;
    };
}

sub descriptor {
    my ( $self, $name ) = @_;
    Storable::dclone( $self->descriptors->{ $name } );
}

#===========================================================================
# FIELD TYPES
#===========================================================================

sub oid {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Oid->new( %opts );
}

sub integer {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Integer->new( %opts );
}

sub string {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::String->new( %opts );
}

sub text {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Text->new( %opts );
}

sub float {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Float->new( %opts );
}

sub email {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Email->new( %opts );
}

sub url {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Url->new( %opts );
}

sub enum {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Enum->new( %opts );
}

sub file {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::File->new( %opts );
}

sub password {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Password->new( %opts );
}

sub boolean {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Boolean->new( %opts );
}

sub date {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Date->new( %opts );
}

sub time {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Time->new( %opts );
}

sub datetime {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::DateTime->new( %opts );
}

sub range {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Range->new( %opts );
}

sub complex {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Complex->new( %opts );
}

sub binary {
    my ( $pkg, %opts ) = @_;
    return Oryx::Schema::Field::Binary->new( %opts );
}

#===========================================================================
# ASSOCIATIONS
#===========================================================================

*ref = \&reference;
sub reference {
    my ( $pkg, $type, %opts ) = @_;
    return Oryx::Schema::Ref->new( $type, %opts );
}

sub list {
    my ( $pkg, $type, %opts ) = @_;
    return Oryx::Schema::List->new( $type, %opts );
}

sub hash {
    my ( $pkg, $type, %opts ) = @_;
    return Oryx::Schema::Hash->new( $type, %opts );
}

sub array {
    my ( $pkg, $type, %opts ) = @_;
    return Oryx::Schema::Array->new( $type, %opts );
}

sub ihash {
    my ( $pkg, $type, %opts ) = @_;
    return Oryx::Schema::IntrHash->new( $type, %opts );
}

sub iarray {
    my ( $pkg, $type, %opts ) = @_;
    return Oryx::Schema::IntrArray->new( $type, %opts );
}


#===========================================================================
# DEPLOYMENT
#===========================================================================

sub deploy {
    my $self = shift;
    for my $meta ( values %{ $self->classes } ) {
        eval { $self->deploy_class( $meta ) };
        croak( "ERROR while deploying ".$meta->name." - $@" ) if $@;
    }
}

sub deploy_class {
    my ( $self, $meta ) = @_;
    return if $self->deployed->{ $meta->name }++;

    my $table  = $meta->table;
    my $class  = $meta->name;
    my $engine = $self->storage->engine;

    my $int = $engine->type2sql('integer');
    my $oid = $engine->type2sql('oid');

    my @cols = $meta->columns;
    my @pkey = $meta->primary;
    my @sizes = $meta->column_sizes;
    my @types = $meta->column_types;

    @types = map {
        $engine->type2sql( $types[$_], $sizes[$_] || '' )
    } 0 .. $#types;
    
    $self->deploy_table( $table, \@cols, \@types, \@pkey );

    $engine->create_sequence( $table )
        unless $engine->sequence_exists( $table );

    foreach my $assoc ( values %{ $meta->assocs } ) {
        $table = $assoc->table || next;
        if ( $assoc->can( 'other' ) and defined( $assoc->other ) ) {
            $self->deploy_class( $assoc->other->meta );
        }
        @cols = $assoc->columns;
        @pkey = $assoc->primary;
        @types = $assoc->column_types;
        @sizes = $assoc->column_sizes;

        @types = map {
            $engine->type2sql( $types[$_], $sizes[$_] || '' )
        } 0 .. $#types;

        $self->deploy_table( $table, \@cols, \@types, \@pkey );
    }
}

sub deploy_table {
    my ( $self, $table, $fields, $types, $pkey ) = @_;

    my $engine = $self->storage->engine;
    if ( $engine->table_exists( $table ) ) {
        for (0 .. @$fields - 1 ) {
            unless ( $engine->column_exists( $table, $fields->[$_] ) ) {
                $engine->create_column(
                    $table, $fields->[$_], $types->[$_]
                );
            }
        }
    } else {
        $engine->create_table( $table, $fields, $types, $pkey );
    }
}

1;
