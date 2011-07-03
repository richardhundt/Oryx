package Oryx::Schema::Field::Url;

use strict;
use warnings;

use URI;
use Oryx::Error;

our $PATTERN = qr|^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?$|;

use base qw/Oryx::Schema::Field/;

sub type { 'string' }

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    if ( defined $value and $value !~ $PATTERN ) {
        die Oryx::Error::Validation->new( "`$value' does not look like a URI", 1 );
    }
}

sub load {
    my ( $self, $object ) = @_;
    my $value = $object->record->{ $self->name };
    if ( defined $value ) {
        $object->record->{ $self->name } = URI->new( $value );
    }
}

1;
