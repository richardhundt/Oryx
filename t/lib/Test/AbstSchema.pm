package Test::AbstSchema;

use strict;
use warnings;

use base qw/Oryx::Schema/;

__PACKAGE__->define(
    'My::Object' => {
        abstract => 1,
    },

    'My::Type1' => {
        base => 'My::Object',
        fields => [
            field1 => [ 'string' ],
            field2 => [ 'string' ],
        ],
    },

    'My::Type2' => {
        base => 'My::Object',
        fields => [
            field1 => [ 'string' ],
            field2 => [ 'string' ],
        ],
    }
);

1;
