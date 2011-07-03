package Test::Schema;

use strict;

use base qw/Oryx::Schema/;

__PACKAGE__->define(
    'My::User' => {
        base => 'My::Person',
        fields => [
            lastname  => [ string => size => 32 ],
            username  => [ string => size => 32 ],
            form_data => [ 'complex' ],
        ],
        assocs => [
            articles => [ list => 'My::Article', compos => 1 ],
            notes    => [ hash => [ 'string', size => 255 ], compos => 1 ],
        ],
    },

    'My::Person' => {
        fields => [
            address_1 => [ 'string', size => 127  ],
            address_2 => [ 'string', size => 127  ],
            firstname => [ 'string', size => 32   ],
        ],
        assocs => [
            login => [ 'ref' => 'My::Login', compos => 1 ],
        ],
    },

    'My::Company' => {
        base => 'My::Person',
        fields => [
            status => [ 'string' ],
            email  => [ 'email', required => 1 ],
        ],
    },

    'My::Login' => {
        fields => [
            usname => [ 'string',   size => 32 ],
            passwd => [ 'password', size => 32 ],
        ]
    },

    'My::Article' => {
        fields => [
            title   => [ 'string', search => 1, weight => 0.5, size => 31 ],
            summary => [ 'text',   search => 1, weight => 0.2 ],
            rating  => [ 'range', min => 0, max => 100 ],
            status  => [ 'enum', items => [qw/ published working deleted /] ],
        ],
        assocs => [
            chapters => [ 'hash', [ 'ref' => 'My::Chapter' ], compos => 1 ],
            author   => [ 'ref' => 'My::User' ],
        ]
    },

    'My::Chapter' => {
        fields => [
            title => [ 'string', size => 127 ],
        ],
        assocs => [
            pages => [ array => [ 'ref' => 'My::Page', compos => 1 ] ],
        ]
    },

    'My::Page' => {
        fields => [
            title => [ 'string' ],
        ],
        assocs => [
            paragraphs => [ 'array' => [ 'text' ] ],
        ]
    }
);

1;
