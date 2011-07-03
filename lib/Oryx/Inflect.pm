package Oryx::Inflect;

use strict;
use warnings;

our $_inflector;
sub inflector {
    return $_inflector if $_inflector;
    my $class = shift;
    $_inflector = bless {
        uncountables => [qw(
            equipment
            information
            rice
            money
            species
            series
            fish
            sheep
        )],
    }, $class;
}

sub singular {
    my ( $self, $word ) = @_;
    return '' unless defined $word;
    $word = lc $word;
    unless ( grep { $word eq $_ } @{ $self->{uncountables} } ) {
        while (1) {
            if ( $word eq 'people'   ) { $word = 'person'; last }
            if ( $word eq 'men'      ) { $word = 'man';    last }
            if ( $word eq 'children' ) { $word = 'child';  last }
            if ( $word eq 'sexes'    ) { $word = 'sex';    last }
            if ( $word eq 'moves'    ) { $word = 'move';   last }
            if ( $word eq 'kine'     ) { $word = 'cow';    last }

            last if $word =~ s/(quiz)zes$/$1/;
            last if $word =~ s/(matr)ices$/${1}ix/;
            last if $word =~ s/(vert|ind)ices$/${1}ex/;
            last if $word =~ s/^(ox)en/$1/;
            last if $word =~ s/(alias|status)es$/$1/;
            last if $word =~ s/(octop|vir)i$/${1}us/;
            last if $word =~ s/(cris|ax|test)es$/${1}is/;
            last if $word =~ s/(shoe)s$/$1/;
            last if $word =~ s/(o)es$/$1/;
            last if $word =~ s/(bus)es$/$1/;
            last if $word =~ s/([m|l])ice$/${1}ouse/;
            last if $word =~ s/(x|ch|ss|sh)es$/$1/;
            last if $word =~ s/(m)ovies$/${1}ovie/;
            last if $word =~ s/(s)eries$/${1}eries/;
            last if $word =~ s/([^aeiouy]|qu)ies$/${1}y/;
            last if $word =~ s/([lr])ves$/${1}f/;
            last if $word =~ s/(tive)s$/$1/;
            last if $word =~ s/(hive)s$/$1/;
            last if $word =~ s/([^f])ves$/${1}fe/;
            last if $word =~ s/(^analy)ses$/${1}sis/;
            last if $word =~ s/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$/${1}${2}sis/;
            last if $word =~ s/([ti])a$/${1}um/;
            last if $word =~ s/(n)ews$/${1}ews/;
            last if $word =~ s/s$//;
            last;
        }
    }
    return $word;
}

sub plural {
    my ( $self, $word ) = @_;
    return '' unless defined $word;
    $word = lc $word;
    unless ( grep { $word eq $_ } @{ $self->{uncountables} } ) {
        while (1) {
            if ( $word eq 'person' ) { $word = 'people';   last }
            if ( $word eq 'man'    ) { $word = 'men';      last }
            if ( $word eq 'child'  ) { $word = 'children'; last }
            if ( $word eq 'sex'    ) { $word = 'sexes';    last }
            if ( $word eq 'move'   ) { $word = 'moves';    last }
            if ( $word eq 'cow'    ) { $word = 'kine';     last }

            last if $word =~ s/(quiz)$/${1}zes/;
            last if $word =~ s/(^ox)$/${1}en/;
            last if $word =~ s/([m|l])ouse$/${1}ice/;
            last if $word =~ s/(matr|vert|ind)(?:ix|ex)$/${1}ices/;
            last if $word =~ s/(x|ch|ss|sh)$/${1}es/;
            last if $word =~ s/([^aeiouy]|qu)y$/${1}ies/;
            last if $word =~ s/(hive)$/${1}s/;
            last if $word =~ s/(?:([^f])fe|([lr])f)$/${1}${2}ves/;
            last if $word =~ s/sis$/ses/;
            last if $word =~ s/([ti])um$/${1}a/;
            last if $word =~ s/(buffal|tomat)o$/${1}oes/;
            last if $word =~ s/(bu)s$/${1}ses/;
            last if $word =~ s/(alias|status)/${1}es/;
            last if $word =~ s/(octop|vir)us$/${1}i/;
            last if $word =~ s/(ax|test)is$/${1}es/;
            last if $word =~ s/s$/s/;
            last if $word =~ s/$/s/;
            last;
        }
    }
    return $word;
}

1;

