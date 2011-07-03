package Oryx::Schema::Field::DateTime;

use strict;
use warnings;

use Date::Format qw/time2str/;
use Date::Parse  qw/str2time/;

use base qw/Oryx::Schema::Field/;

sub new {
    my ( $class, %opts ) = @_;
    my $self = $class->SUPER::new( %opts );
    $self->{format} = $opts{format} || '%Y-%m-%d %H:%M:%S';
    bless $self, $class;
}

sub type { 'datetime' }

sub load {
    my ( $self, $object ) = @_;
    my $value = $object->record->{ $self->name };
    if ( defined $value ) {
        $object->record->{ $self->name } = str2time( $value );
    }
}

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    if ( defined $value ) {
        $value = time if $value eq 'now';
        if ( $value =~ /^\d+$/ ) {
            $object->record->{ $self->name } = time2str( $self->{format}, $value );
        }
    }
}

1;
