package Oryx::Schema::Assoc;

use strict;
use warnings;

use Carp;
use SQL::Abstract;

sub key { }

sub class {
    my $self = shift;
    $self->{class} = shift if @_;
    $self->{class};
}
sub query {
    my $self = shift;
    $self->{query} ||= SQL::Abstract->new;
}
sub setup {
    my ( $self, $class ) = @_;
    $self->columns();
}

sub table { }
sub primary { }
sub columns { }
sub column_types { }
sub column_sizes { }
sub column_extra { }

sub name { die "abstract" }
sub bind { die "abstract" }

sub storage { shift->{class}->meta->storage }

1;
