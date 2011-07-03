package Oryx::Search::TermQuery;

use strict;
use warnings;

use Carp qw/croak/;

use base qw/Oryx::Search::Query/;

sub new {
    my ( $class, %args ) = @_;
    my $self = bless {
        term => delete $args{term} || croak( 'Need a term' ),
    }, $class;
    $self;
}

sub term { shift->{term} }

sub prepare {
    my ( $self, $searcher ) = @_;
    my ( $word ) = @{ $searcher->stemmer->stem( $self->{term}->text ) };
    $self->{word} = $word;
}

sub where {
    my $self = shift;
    return "( word=? AND field=? )", $self->{word}, $self->term->field;
}


1;
