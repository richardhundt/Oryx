use lib './lib';
use lib './t/lib';

use strict;
use warnings;

use Test::More qw/no_plan/;

use Oryx::Storage;

my $storage = Oryx::Storage->new(
    dsn => 'dbi:SQLite:dbname=testdb',
    username => '',
    password => '',
);

$storage->open( 'Test::IntrSchema' );
$storage->deploy;

my $u1 = My::User->new( firstname => 'Jack' );

ok( defined $u1 );
$u1->lastname( 'Random' );
$u1->save;

my $oid = $u1->oid;
ok( $oid );
ok( $u1->lock_version == 1 );
undef( $u1 );

$u1 = My::User->fetch( $oid );

$u1->notes->{general} = "clever";
$u1->save;

is( $u1->notes->{general}, 'clever' );

my $a1 = My::Article->new( title => 'Meta Mania' );
ok( defined $a1 );
$a1->chapters->{chapter_1} = My::Chapter->new( title => 'Chapter 1' );
$a1->save();
ok( $a1 ); # oid check (overloaded +0 --> bool)
$oid = $a1->oid;

undef( $a1 );
$a1 = My::Article->fetch( $oid );
ok( exists $a1->chapters->{chapter_1} );
is( $a1->chapters->{chapter_1}->title, 'Chapter 1' );

#vim: ft=perl

