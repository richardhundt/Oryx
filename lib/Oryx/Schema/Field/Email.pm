package Oryx::Schema::Field::Email;

use strict;
use warnings;

use Oryx::Error;

use base qw/Oryx::Schema::Field/;

our $PATTERN = qr/^[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,4}$/i;

sub type { 'string' }

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    if ( defined $value and $value !~ $PATTERN ) {
        die Oryx::Error::Validation->new(
            "`$value' does not look like an email address", 1 
        );
    }
}

1;
