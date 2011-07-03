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

my $u1 = My::User->new(
    firstname => 'Test',
    lastname  => 'User',
);

ok( defined $u1, 'created a user' );

my $a1 = My::Article->new( title => 'Cheese on Toast' );
ok( defined $a1 );
my $a2 = My::Article->new( title => 'Cheese and Chutney' );
ok( defined $a2 );

$u1->articles->insert( $a1 );
$u1->articles->insert( $a2 );
$u1->save;

my $oid = $u1->oid;

undef( $u1 );

$u1 = My::User->fetch( $oid );
ok( defined $u1->articles->contains( $a1 ) );
ok( defined $u1->articles->contains( $a2 ) );
is( $u1->articles->retrieve( $a1 ), $a1 );
is( $u1->articles->retrieve( $a1 )->title, 'Cheese on Toast' );

#vim: ft=perl

