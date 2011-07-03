package Oryx::Schema::Field::Range;

use strict;
use warnings;

use POSIX qw/fmod/;
use Oryx::Error;

use base qw/Oryx::Schema::Field/;

sub new {
    my ( $class, %opts ) = @_;

    die "need a min" unless defined $opts{min};
    die "need a max" unless defined $opts{max};
    $opts{step} ||= 1;

    my $self = bless $class->SUPER::new( %opts ), $class;
    $self;
}

sub type {
    my $self = shift;
    return fmod( $self->{step}, 1 ) == 0 ? 'integer' : 'float';
}

sub save {
    my ( $self, $object ) = @_;
    my $val = $self->SUPER::save( $object );
    return unless defined $val;

    my $min = $self->{min};
    my $max = $self->{max};
    unless ( $val >= $min and $val <= $max and fmod($val, $self->{step}) == 0 ) {
        die Oryx::Error::Validation->new("`$val' is out of range", 1);
    }
}

1;
