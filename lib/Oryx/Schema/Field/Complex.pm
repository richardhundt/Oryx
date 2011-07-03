package Oryx::Schema::Field::Complex;

use strict;

use JSON ();
use Scalar::Util ();

use base qw/Oryx::Schema::Field/;

our $CODEC = JSON->new;

sub type { 'text' }

sub load {
    my ( $self, $object ) = @_;
    my $value = $object->record->{ $self->name };
    if ( defined $value ) {
        $object->record->{ $self->name } = $CODEC->decode( $value );
    }
}

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    return if Scalar::Util::blessed( $value );
    if ( defined $value ) {
        $object->record->{ $self->name } = $CODEC->encode( $value );
    }
}

1;
