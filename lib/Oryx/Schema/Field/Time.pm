package Oryx::Schema::Field::Time;

use strict;
use warnings;

use base qw/Oryx::Schema::Field::DateTime/;

sub new {
    my ( $class, %opts ) = @_;
    my $self = $class->SUPER::new( %opts );
    $self->{format} = $opts{format} || '%H:%M:%S';
    bless $self, $class;
}

sub type { 'time' }

1;
