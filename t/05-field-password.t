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

my $login = My::Login->new(
    usname => 'theboss',
    passwd => 'secret',
);

$login->save();
ok( $login->oid, 'login has an oid' );

my $oid = $login->oid;
undef( $login  );

$login = My::Login->fetch( $oid );
ok( $login );
ok( $login->usname eq 'theboss' );
ok( $login->passwd eq 'secret' );

$login->save();
ok( $login->passwd eq 'secret' );


#vim: ft=perl

