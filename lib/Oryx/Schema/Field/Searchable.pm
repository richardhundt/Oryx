package Oryx::Schema::Field::Searchable;

use strict;
use warnings;

use base qw/Oryx::Schema::Field/;

sub save {
    my ( $self, $object ) = @_;
    my $value = $self->SUPER::save( $object );
    if ( $self->{search} ) {
        $self->indexer->update(
            oid => $object->oid,
            ver => $object->lock_version,
            field => $self,
            value => $value,
        );
    }
    return $value;
}

sub weight  { shift->{weight} ||= 1 }
sub indexer { shift->class->meta->indexer }

1;
