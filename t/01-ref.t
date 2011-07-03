use lib './lib';
use lib './t/lib';

use strict;
use warnings;

use Test::More qw/no_plan/;

use Test::Schema;
use Data::Dumper;
use My::Person;

use Oryx::Storage;

my $storage = Oryx::Storage->new(
    dsn => 'dbi:SQLite:dbname=testdb',
    username => '',
    password => '',
);

$storage->open( 'Test::Schema' );
$storage->deploy;

my $person = My::Person->new(
    address_1 => '11 Broad Lane',
    address_2 => 'Hampton',
);

$person->firstname( 'Acme Inc' );

my $login = My::Login->new(
    usname => 'theboss',
    passwd => 'secret',
);

$login->save();
ok( $login->oid, 'login has an oid' );

$person->login( $login );
$person->save();
my $oid = $person->oid;

ok( $oid, "person has an oid" );

undef( $person );
undef( $login  );

$person = My::Person->new( id => $oid );
$person->load();
$login = $person->login;

ok( $login );
ok( $login->usname eq 'theboss' );

my $login2 = My::Login->new(
    usname => 'newboss',
    passwd => 'secret',
);

$login2->save();
$person->login( $login2 );
$person->save();

my $poid = $person->oid;

$oid = $login2->oid;
ok( $oid );

undef( $person );
undef( $login2 );

$person = My::Person->new( id => $poid );
$person->load();
$login2 = $person->login;

is( $login2->oid, $oid );

$person->firstname( 'Acme Inc.' );
$person->save();
$person->lock_version(1);
$person->firstname( 'Not This' );

eval { $person->save() };

ok( $@, 'caught eval error' );
ok( $@->isa( 'Oryx::Error::StaleObject' ) );

my $p1 = My::Person->fetch( $poid );
my $p2 = My::Person->fetch( id => $poid );

$p1->firstname( 'Metadigm' );
$p1->save();

eval {
    $p2->firstname( 'Not This' );
    $p2->save();
};
ok( $@ and $@->isa( 'Oryx::Error::StaleObject' ) );

#vim: ft=perl

