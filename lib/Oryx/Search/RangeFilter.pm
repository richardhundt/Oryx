package Oryx::Search::RangeFilter;

use strict;
use warnings;

use Carp qw/croak/;

use base qw/Oryx::Search::Filter/;

sub new {
    my ( $class, %args ) = @_;
    my $self = bless {
        field => delete $args{field} || croak( 'Need a field' ),
        lower => delete $args{lower} || croak( 'Need a lower bound' ),
        upper => delete $args{upper} || croak( 'Need an upper bound' ),
    }, $class;
    $self;
}

sub field { shift->field }

sub where {
    my $self = shift;
    my $field = ref( $self->field ) ? $field->name : $self->field;
    return "( $field >= ? AND $field =< ? )", $self->{lower}, $self->{upper};
}

1;
