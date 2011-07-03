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
    title => 'Range Test',
    rating => 75,
);

ok( defined $a1 );
$a1->save;

my $oid = $a1->oid;

undef( $a1 );

$a1 = My::Article->fetch( $oid );
is( $a1->rating, 75 );

$a1->rating( -2 );
eval { $a1->save() };
ok($@);
is(ref $@, 'Oryx::Error::Validation');

#vim: ft=perl

