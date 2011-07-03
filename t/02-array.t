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

$storage->open( 'Test::Schema' );
$storage->deploy;

my $page = My::Page->new(
    title => 'Metamania',
);

ok( defined $page, 'created a page' );

$page->paragraphs->push( 'This is paragraph 1' );
$page->paragraphs->push( 'This is paragraph 2' );

is( scalar @{ $page->paragraphs }, 2, 'got 2 paragraphs' );
$page->save();
is( scalar @{ $page->paragraphs }, 2, 'still 2 paragraphs' );

my $oid = $page->oid;

undef( $page );

$page = My::Page->new( id => $oid );
$page->load;

is( $page->oid, $oid, 'oids match' );
is( scalar @{ $page->paragraphs }, 2, 'got 2 paragraphs' );
is( $page->paragraphs->[0], 'This is paragraph 1' );
is( $page->paragraphs->[1], 'This is paragraph 2' );

my $chapter = My::Chapter->new( title => 'The Art of Objects' );

ok( defined $chapter, "created a chapter" );
$chapter->pages->push( $page );
is( scalar( @{ $chapter->pages } ), 1, "got one page in chapter" );
$chapter->save();
$oid = $chapter->oid;

undef( $chapter );

$chapter = My::Chapter->new( id => $oid );
ok( defined $chapter->pages->[0], "page fetched from chapter" );
is( $chapter->pages->[0]->paragraphs->[0], 'This is paragraph 1', 'array ref retrieval' );

my $page1 = My::Page->new(
    title => 'MultiSave1',
);
my $page2 = My::Page->new(
    title => 'MultiSave2',
);

$chapter->pages->push( $page1 );
$chapter->save();

$chapter->pages->push( $page2 );
$chapter->save();

is( @{ $chapter->pages }, 3 );

#vim: ft=perl

