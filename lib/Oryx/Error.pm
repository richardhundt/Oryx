package Oryx::Error;

use strict;
use warnings;

use overload '""' => \&message;

sub new {
    my ( $class, $message, $level ) = @_;
    $level = defined $level ? $level : 0;
    my ( $package, $file, $line ) = caller( $level );
    my $self = "$class - $message at $file line $line\n";
    bless \$self, $class;
}

sub message { ${ shift() } }

package Oryx::Error::StaleObject;
use base qw/Oryx::Error/;

package Oryx::Error::Validation;
use base qw/Oryx::Error/;
1;
