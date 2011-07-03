package Oryx::Search::Term;

use strict;
use warnings;

sub new {
    my ( $class, $field, $text ) = @_;
    my $self = bless {
        field => $field,
        text  => $text,
    }, $class;
    $self;
}

sub field { shift->{field} }
sub text  { shift->{text}  }

1;
