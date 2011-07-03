package Oryx::Schema::Meta;

use strict;

use Carp qw/carp croak/;

use SQL::Abstract;

use Oryx::Error;
use Oryx::Search::Indexer;
use Oryx::Util qw/class2table class2fkey/;

sub new {
    my ( $class, %params ) = @_;
    my $self = bless {
        name   => $params{name},
        schema => $params{schema},
        base   => undef,
        fields => { },
        assocs => { },
        query  => SQL::Abstract->new,
    }, $class;

    return $self;
}

sub key      { 'id'  }
sub key_type { 'oid' }

*class = \&name;
sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    $self->{name};
}

sub schema { $_[0]{schema} }

sub storage { shift->{schema}->storage }

sub indexer {
    my $self = shift;
    $self->{indexer} ||= Oryx::Search::Indexer->new( class => $self->name );
}

sub query { shift->{query} }

sub field {
    my ( $self, $name, $type ) = @_;
    if ( $type ) {
        die "$type is not a valid field type"
            unless UNIVERSAL::isa( $type, 'Oryx::Schema::Field' );
        $self->{fields}{$name} = $type;
        $type->name( $name );
        $type->class( $self->name );
    }
    $self->{fields}{$name};
}

sub fields {
    my $self = shift;
    if ( @_ ) {
        my @fields = @_;
        while ( my ( $name, $type ) = splice( @fields, 0, 2 ) ) {
            $self->field( $name, $type );
        }
    }
    $self->{fields};
}

sub valid {
    my $self = shift;
    $self->{valid} ||= do {
        my %valid;
        @valid{( $self->columns )} = ( $self->column_types );
        foreach my $assoc ( values %{ $self->{assocs} } ) {
            next unless ( $assoc->table eq $self->table );
            @valid{ $assoc->columns } = ( $assoc->column_types );
        }
        if ( $self->{base} ) {
            my $base = $self->{base}->meta;
            @valid{( $base->columns )} = ( $base->column_types );
        }
        \%valid;
    };
}

sub assoc {
    my ( $self, $name ) = ( shift, shift );
    if ( @_ ) {
        my $type = shift;
        die "$type is not a valid assoc type"
            unless UNIVERSAL::isa( $type, 'Oryx::Schema::Assoc' );
        $self->{assocs}{$name} = $type;
        $type->name( $name );
        $type->class( $self->name );
    }
    else {
        return $self->{assocs}{ $name } if exists $self->{assocs}{ $name };
        return $self->{base}->meta->assoc( $name ) if $self->{base};
    }
}

sub assocs {
    my $self = shift;
    if ( @_ ) {
        my @assocs = @_;
        while ( my ( $name, $type ) = splice( @assocs, 0, 2 ) ) {
            $self->assoc( $name, $type );
        }
    }
    $self->{assocs};
}

sub base {
    my $self = shift;
    if ( @_ and defined $_[0] ) {
        my $base = shift;
        croak( "Multiple inheritance not supported" ) if $self->{base};
        $self->{base} = $base;
        no strict 'refs';
        push @{ $self->{name}.'::ISA' }, $base;
    }
    $self->{base};
}

sub abstract {
    my $self = shift;
    $self->{abstract} = shift if @_;
    $self->{abstract};
}

sub table {
    my $self = shift;
    $self->{table} ||= do {
        my $table;
        if ( $self->{base} ) {
            $table = $self->{base}->meta->table;
        } else {
            $table = class2table( $self->name );
        }
    };
}

sub primary {
    my $self = shift;
    $self->{primary} ||= [ 'id' ];
    wantarray ? @{ $self->{primary} } : $self->{primary};
}

sub columns {
    my $self = shift;
    $self->{columns} ||= do {
        my @colms = ( map { $_->name } values %{ $self->fields } );
        if ( $self->{base} ) {
            push @colms, $self->{base}->meta->columns;
        }
        else {
            push @colms, 'lock_version';
            push @colms, 'oryx_isa' if $self->abstract;
            unshift @colms, $self->key;
        }

        foreach my $assoc ( values %{ $self->{assocs} } ) {
            next unless ( $assoc->table eq $self->table );
            push @colms, $assoc->columns;
        }

        \@colms;
    };
    wantarray ? @{ $self->{columns} } : $self->{columns};
}

sub column_types {
    my $self = shift;
    $self->{column_types} ||= do {
        my @types = ( map { $_->type } values %{ $self->fields } );
        if ( $self->{base} ) {
            push @types, $self->{base}->meta->column_types;
        }
        else {
            push @types, 'integer';
            push @types, 'string' if $self->abstract;
            unshift @types, $self->key_type;
        }
        foreach my $assoc ( values %{ $self->{assocs} } ) {
            next unless ( $assoc->table eq $self->table );
            push @types, $assoc->column_types;
        }
        \@types;
    };
    wantarray ? @{ $self->{column_types} } : $self->{column_types};
}

sub column_sizes {
    my $self = shift;
    $self->{column_sizes} ||= do {
        my @sizes = ( map { $_->size } values %{ $self->fields } );
        if ( $self->{base} ) {
            push @sizes, $self->{base}->meta->column_sizes;
        }
        else {
            push @sizes, undef;                     # lock_version
            push @sizes, undef if $self->abstract;  # oryx_isa
            unshift @sizes, undef;                  # key_type
        }
        foreach my $assoc ( values %{ $self->{assocs} } ) {
            next unless ( $assoc->table eq $self->table );
            push @sizes, $assoc->column_sizes;
        }
        \@sizes;
    };
    wantarray ? @{ $self->{column_sizes} } : $self->{column_sizes};
}

1;
