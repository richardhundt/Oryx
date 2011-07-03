package Oryx::Schema::Field::File;

use strict;
use warnings;

use File::Spec;
use IO::File;

use base qw/Oryx::Schema::Field/;

sub new {
    my ( $class, %opts ) = @_;
    my $self = bless $class->SUPER::new( %opts );
    $self->{base} ||= '.';
    $self;
}

sub type { 'string' }

sub save {
    my ( $self, $object ) = @_;

    my $file = $self->SUPER::save( $object );
    return unless defined $file;

    unless ( UNIVERSAL::isa( $file, 'IO::File' ) ) {
        die Oryx::Error::Validation->new( "`$file' not an IO::File", 1 );
    }

    my $path = $self->_outpath( $object );

    $file->seek(0, 0);
    my $data;
    { local $/ = undef;
        $data = <$file>;
        $file->close();
    }

    my $fout = IO::File->new( ">$path" ) or die $!;
    $fout->print( $data );
    $fout->close();

    $object->record->{ $self->name } = $path;
}

sub load {
    my ( $self, $object ) = @_;
    my $path = $object->record->{ $self->name };
    if ( defined $path ) {
        $object->record->{ $self->name } = IO::File->new( "<$path" ) or die $!;
    }
}

sub _outpath {
    my ( $self, $object ) = @_;
    my @dirs = ( $self->{base}, $object->meta->table );
    unless ( $self->{_dirs_checked}++ ) {
        my @seen;
        for my $frag ( @dirs ) {
            push @seen, $frag;
            my $path = File::Spec->catfile( @seen );
            unless ( -e $path and -d _ ) {
                mkdir( $path ) || die $!;
            }
        }
    }
    File::Spec->catfile( @dirs, $self->name.'.'.$object->oid );
}

sub delete {
    my ( $self, $object ) = @_;
    my $path = $self->_outpath( $object );
    unlink $path if ( -e $path and -f _ );
}

1;
