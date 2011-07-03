package Oryx::Search::Indexer;

use strict;
use warnings;

use Oryx::Engine;
use Oryx::Search::Stemmer;
use Oryx::Search::Splitter;

our $MAX_SCORE = 10;

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;
}

sub class { shift->{class} }

sub storage {
    my $self = shift;
    $self->{storage} ||= $self->class->meta->storage;
}

sub table {
    my $self = shift;
    $self->{table} ||= $self->storage->engine->index_table;
}

sub splitter {
    my $self = shift;
    $self->{splitter} = shift if @_;
    $self->{splitter} ||= Oryx::Search::Splitter->new;
}

sub stemmer {
    my $self = shift;
    $self->{stemmer} = shift if @_;
    $self->{stemmer} ||= Oryx::Search::Stemmer->new;
}

sub update {
    my ( $self, %args ) = @_;
    my $oid = $args{oid};
    my $ver = $args{ver};

    my $field = $args{field};
    my $value = $args{value};
    my $table = $self->table;
    my $class = $self->class;
    my $fname = $field->name;

    my ( @words, %words );
    if ( $field->type eq 'string' or $field->type eq 'text' ) {
        @words = $self->splitter->words( $value );
        @words = @{ $self->stemmer->stem( @words ) };
    } else {
        @words = ( $value );
    }

    {
        no warnings 'uninitialized';
        for ( @words{ @words } ) {
            $_ += $field->weight unless $_ > $MAX_SCORE;
        }
    }

    my $sth = $self->storage->dbh->prepare(qq{
        INSERT INTO $table (word, score, class, field, oid, version )
        VALUES (?, ?, ?, ?, ?, ?)
    });

    foreach my $word ( sort keys %words ) {
        $sth->execute( $word, $words{$word}, $class, $fname, $oid, $ver );
    }

    $self->storage->exec(qq{
        DELETE FROM $table WHERE class=? AND oid=? AND version=?
    }, undef, ( $class, $oid, $ver - 1 ) );
}

sub delete {
    my ( $self, %args ) = @_;
    my $oid = $args{oid};
    my $class = $self->class;
    my $table = $self->table;

    $self->storage->exec(qq{
        DELETE FROM $table WHERE class=? AND oid=?
    }, undef, ( $class, $oid ) );
}

1;
