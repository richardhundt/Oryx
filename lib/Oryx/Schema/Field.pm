package Oryx::Schema::Field;

use strict;

use Oryx::Error;

sub new {
    my ( $class, %opts ) = @_;
    my $self = bless { %opts }, $class;
    $self;
}

sub type  { shift->{type}  }
sub size  { shift->{size}  }
sub extra { shift->{extra} }

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    $self->{name};
}

sub class {
    my $self = shift;
    $self->{class} = shift if @_;
    $self->{class};
}

sub setup {
    my ( $self, $class ) = @_;
    $self->{class} = $class->name;
}

sub bind {
    my ( $self, $value ) = @_;
    Oryx::Value->new( $value );
}

sub load { }

sub save {
    my ( $self, $object ) = @_;

    my $value = $object->record->{ $self->name };
    if ( defined $self->{default} and not defined $value ) {
        $value = $self->{default};
        $object->record->{ $self->name} = $value;
    }
    if ( $self->{required} and not defined $value ) {
        die Oryx::Error::Validation->new( $self->name." is required" );
    }

    return $value;
}

sub delete { }


package Oryx::Value;

use strict;
use warnings;

use overload
    '""' => \&fetch,
    '0+' => \&fetch,
    fallback => 1;

sub new {
    my ( $class, $value ) = @_;
    bless { value => $value }, $class;
}

sub fetch {
    my $self = shift;
    $self->{value};
}

sub store {
    my ( $self, $value ) = @_;
    $self->{ value } = $value;
    $self->{changed}++;
}

sub save {
    my ( $self, $object ) = @_;
    return unless $self->{changed};
    my $name = $self->meta->name;
    $object->$name( $self->{value} );
}

1;
