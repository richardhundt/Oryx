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

open ( my $fh, '<./t/world95.txt' );
my @data;
{
    local $/ = undef;
    my $data = <$fh>;
    @data = split /_{72}/, $data, 102;
    shift @data;
    pop @data;
    close $fh;
}

sub get_data {
    return shift @data;
}

for ( 0 .. 99 ) {
    my $a1 = My::Article->new(
        title => "Index Testing $_",
        summary => get_data(),
    );

    $a1->save;
    ok( defined $a1 );
}

use Oryx::Search::Term;
use Oryx::Search::TermQuery;

my $t1 = Oryx::Search::Term->new( 'summary' => 'domestic' );
my $q1 = Oryx::Search::TermQuery->new( term => $t1 );

my $h1 = My::Article->search( query => $q1 );
ok( $h1 );
ok( scalar(@{ $h1->{list} }) > 40 );

#vim: ft=perl

