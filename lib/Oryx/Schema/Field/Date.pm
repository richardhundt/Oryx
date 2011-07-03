package Oryx::Schema::Field::Date;

use strict;

use base qw/Oryx::Schema::Field::DateTime/;

sub new {
    my ( $class, %opts ) = @_;
    my $self = $class->SUPER::new( %opts );
    $self->{format} = $opts{format} || '%Y-%m-%d';
    bless $self, $class;
}

sub type { 'date' }

1;
