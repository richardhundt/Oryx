package Oryx::Util;

use strict;

use Oryx::Inflect;

use base qw/Exporter/;

our @EXPORT_OK = qw/
    file2class class2file class2field class2table class2fkey inflector
/;

sub inflector { Oryx::Inflect->inflector }

sub class2table {
    inflector->plural( class2field( pop ) );
}

sub class2field {
    lc( ( pop =~ /([^:]+)$/ )[0] );
}

sub class2fkey {
    class2field( pop ).'_id';
}

sub file2class {
    my $file = pop;
    $file =~ s/\.pmc?$//;
    join( '::', split /\//, $file );
}

sub class2file {
    my $class = pop;
    join( '/', split /::/, $class ).'.pm';
}

1;
