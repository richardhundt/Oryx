use lib './lib';
use lib './t/lib';

use strict;
use warnings;

use Test::More qw/no_plan/;
use Data::Dumper;

use Oryx::Storage;

my $storage = Oryx::Storage->new(
    dsn => 'dbi:SQLite:dbname=abstdb',
    username => '',
    password => '',
);

$storage->open( 'Test::AbstSchema' );
$storage->deploy;

my $t1 = My::Type1->new(
    field1 => 'Isaac',
    field2 => 'Asimov',
);

ok(defined $t1);

$t1->save();
ok($t1->oid);
ok($t1->field1() eq 'Isaac');
ok($t1->field2() eq 'Asimov');

my $t1_id = $t1->oid;
undef($t1);

my $t1_2 = My::Object->new( $t1_id );
$t1_2->load();

ok($t1_2->oid == $t1_id);
is($t1_2->field1, 'Isaac');
is($t1_2->field2, 'Asimov');

undef($t1_2);

my $t1_3 = My::Type1->new( $t1_id );
$t1_3->load();
ok($t1_3->oid == $t1_id);
is($t1_3->field1, 'Isaac');
is($t1_3->field2, 'Asimov');

my $t2 = My::Type2->new(
    field1 => 'Richard',
    field2 => 'Hundt',
);

ok(defined $t2);

$t2->save();
ok($t2->oid);
ok($t2->field1() eq 'Richard');
ok($t2->field2() eq 'Hundt');

my $t2_id = $t2->id;

undef( $t2 );
$t2 = My::Object->new( $t2_id );
$t2->load();

is(ref $t2, 'My::Type2');
ok($t2->field1() eq 'Richard');
ok($t2->field2() eq 'Hundt');


#vim: ft=perl

