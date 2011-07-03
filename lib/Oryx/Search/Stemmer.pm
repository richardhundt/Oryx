package Oryx::Search::Stemmer;

use Lingua::Stem;

sub new {
    my $class = shift;

    my $_stemmer = Lingua::Stem->new( -locale => 'EN' );
    $_stemmer->stem_caching({ -level => 2 });

    my $self = bless {
        _stemmer => $_stemmer,
    }, $class;
    return $self;
}

sub stem { shift->{_stemmer}->stem(@_) }

1;
