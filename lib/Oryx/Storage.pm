package Oryx::Storage;

use strict;
use warnings;

use DBI;
use Carp qw/carp croak/;
use Oryx::Engine;
use Oryx::Schema;

our $DEBUG = 0;

sub new {
    my $class = shift;
    my $config = ref $_[0] ? $_[0] : {@_};
    my $self = bless {
        config => $config,
    }, $class;
    $self->init();
    return $self;
}

sub init {
    my $self = shift;
    my $conf = $self->{ config };
    my $pass = delete $conf->{ password };
    $conf->{ password } = sub { $pass };
}

sub open {
    my ( $self, $schema ) = @_;
    eval "use $schema"; die $@ if $@;

    $self->{schema} = $schema;
    $self->dbh();

    $schema->storage( $self );
    $self;
}

sub schema { $_[0]->{schema} }

sub engine {
    my $self = shift;
    $self->{engine} ||= do {
        my $dsn = $self->{ config }{ dsn };
        my ( $driver ) = ( $dsn =~ /dbi:(\w+):/ );
        Oryx::Engine->create( $driver, $self->{ config } );
    }
}

sub dbh { shift->engine->dbh }

sub list {
    my ( $self, $stmt, $attr, @bind ) = @_;
    $attr ||= { Slice => { } };
    $DEBUG && carp "LIST: $stmt";
    $self->dbh->selectall_arrayref($stmt, $attr, @bind);
}

sub exec {
    my ( $self, $stmt, $attr, @bind ) = @_;
    $attr ||= { };
    {
        no warnings 'uninitialized';
        $DEBUG && carp "QUERY: $stmt\n BIND: ".join(',',@bind);
    }
    $self->dbh->do($stmt, $attr, @bind);
}

sub nextval {
    shift->engine->nextval(@_);
}

sub atomic {
    shift->engine->atomic(@_);
}

sub begin {
    shift->engine->begin();
}

sub rollback {
    shift->engine->rollback();
}

sub commit {
    shift->engine->commit();
}

sub class {
    my ( $self, $name ) = @_;
    return $self->schema->classes->{$name}
        || croak( "class $name not found in schema" );
}

sub deploy {
    my ( $self ) = @_;
    $self->schema->deploy();
}

sub deploy_schema {
    my ( $self, $schema ) = @_;
    $schema->storage( $self );
    $schema->deploy();
}

sub config { $_[0]{config} }

1;
