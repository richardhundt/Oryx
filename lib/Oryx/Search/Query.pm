package Oryx::Search::Query;

use strict;
use warnings;

use Carp qw/confess/;

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;
}

sub where { confess "abstract" }

1;
