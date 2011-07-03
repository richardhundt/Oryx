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

my $c1 = My::Company->new(
    email  => 'richard@email.com',
    status => 'operational',
);

ok(defined $c1);

$c1->save();
my $oid = $c1->oid;
undef $c1;

$c1 = My::Company->fetch( $oid );
ok($c1);

my $c2 = My::Company->new(
    status => 'bellyup',
);
eval { $c2->save() };

ok($@);
is( ref $@, 'Oryx::Error::Validation' );
ok( $@->message =~ /email is required/ );

#vim: ft=perl

