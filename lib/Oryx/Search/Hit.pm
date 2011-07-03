package Oryx::Search::Hit;

use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;
}

sub class { shift->{class} }
sub score { shift->{record}{oryx_idx_score} }
sub count { shift->{record}{oryx_idx_count} }

sub record { shift->{record} }
sub object {
    my $self = shift;
    $self->{class}->new( $self->{record} );
}

1;
