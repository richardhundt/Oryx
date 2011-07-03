package Oryx::Search::Filter;

use strict;
use warnings;

use Carp qw/croak/

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;
}

sub where {
    my $self = shift;
    $self->{where} = shift if @_;
    $self->{where} ||= ' ';
}

sub accept {
    my ( $self, $hit ) = @_;
    return $self->{accept}->( $hit ) if $self->{accept};
    return $hit;
} 

sub prepare { }

1;
