use lib './lib';
use lib './t/lib';

use strict;
use warnings;

use Test::More qw/no_plan/;

use Data::Dumper;
use Oryx::Storage;

my $storage = Oryx::Storage->new(
    dsn => 'dbi:SQLite:dbname=testdb',
    username => '',
    password => '',
);

$storage->open( 'Test::Schema' );
$storage->deploy;

my $u1 = My::User->new( firstname => 'complex', lastname => 'user' );
ok( defined $u1 );
$u1->form_data({ 'foo' => [ '1', 42, 'baz' ] });
$u1->save;

my $oid = $u1->oid;

undef( $u1 );

$u1 = My::User->fetch( $oid );
is( ref( $u1->form_data ), 'HASH' );
is( ref( $u1->form_data->{foo} ), 'ARRAY' );
is( $u1->form_data->{foo}[0], '1' );
is( $u1->form_data->{foo}[1], 42 );
is( $u1->form_data->{foo}[2], 'baz' );

#vim: ft=perl

