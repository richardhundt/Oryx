use inc::Module::Install;

name('Oryx');
author('Richard Hundt <perl@kulabs.com>');
abstract('Object Data Management System');
license('artistic');
version_from('lib/Oryx.pm');
build_requires('Test::More');
test_requires( 'DBD::SQLite' );

my @depends = qw/
    DBI
    Carp
    JSON
    JSON::XS
    Scalar::Util
    Class::Data::Inheritable
    SQL::Abstract
    Lingua::Stem
/;

requires( map { $_ => undef } @depends );

check_nmake();
&WriteAll();
