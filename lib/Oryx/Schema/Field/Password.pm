package Oryx::Schema::Field::Password;

use strict;
use warnings;

use base qw/Oryx::Schema::Field/;

sub VALUE ( ) { 'Oryx::Schema::Field::Password::Value' }

sub type { 'string' }

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    unless ( UNIVERSAL::isa( $value, VALUE ) ) {
        $object->record->{ $self->name } = VALUE->new(
            value => crypt( $value, $self->name ),
            salt  => $self->name,
        );
    }
}

sub load {
    my ( $self, $object ) = @_;
    my $value = $object->record->{ $self->name };
    if ( defined $value ) {
        $object->record->{ $self->name } = VALUE->new(
            value => $value,
            salt  => $self->name,
        )
    }
}


package Oryx::Schema::Field::Password::Value;

use strict;

use overload
    '""'  => \&as_string,
    'cmp' => \&compare,
    fallback => 1;

sub new {
    my ( $class, %args ) = @_;
    return bless {
        value => delete $args{value},
        salt  => delete $args{salt},
    }, $class;
}

sub as_string {
    my $self = shift;
    return $self->{value};
}

sub compare {
    my ( $self, $other ) = @_;
    return crypt( $other, $self->{salt} ) cmp $self->{value};
}

1;
