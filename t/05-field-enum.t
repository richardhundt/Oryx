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

my $a1 = My::Article->new(
    status => 'working',
);

ok(defined $a1);

$a1->save();
my $oid = $a1->oid;
undef $a1;

$a1 = My::Article->fetch( $oid );
ok($a1);

my $a2 = My::Article->new(
    status => 'bellyup',
);
eval { $a2->save() };

ok($@);
is( ref $@, 'Oryx::Error::Validation' );
ok( $@->message =~ /not a member of/ );

#vim: ft=perl

