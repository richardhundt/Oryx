package Oryx::Schema::Field::Enum;

use strict;

use Oryx::Error;

use base qw/Oryx::Schema::Field/;

sub new {
    my ( $class, %opts ) = @_;
    my $self = bless $class->SUPER::new( %opts ), $class;
    $self->{items} ||= [ ];
    return $self;
}

sub type { 'string' }

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    if ( defined $value ) {
        unless ( grep { $value eq $_ } @{ $self->{items} } ) {
            die Oryx::Error::Validation->new(
                "`$value' not a member of @{$self->{items}}", 1
            );
        }
    }
}

1;

