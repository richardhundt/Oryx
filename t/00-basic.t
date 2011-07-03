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
    firstname => 'Isaac',
    lastname  => 'Asimov',
);

ok(defined $u1);

$u1->save();

ok($u1->oid);
is($u1->firstname, 'Isaac');
is($u1->lastname, 'Asimov');

$u1->firstname('Jordy');
is($u1->firstname, 'Jordy');
is($u1->lock_version, 1);

$u1->save();
is($u1->lock_version, 2);

my $oid = $u1->oid;

undef($u1);
$u1 = My::User->fetch($oid);
is($u1->lock_version, 2);

is($u1->firstname, 'Jordy');
is($u1->lastname, 'Asimov');

$u1->delete();
ok( $u1->isa('Oryx::DeadBeef') );
ok( scalar( %$u1 ) == 0 );

#vim: ft=perl

