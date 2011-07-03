package Oryx::Search::HitList;

use strict;
use warnings;

use Oryx::Search::Hit;

sub new {
    my ( $class, %args ) = @_;
    my $self = bless {
        list => $args{list},
        class => $args{class},
        filter => $args{filter},
        counter => 0,
    }, $class;
    return $self;
}

sub list { shift->{list} }
sub class { shift->{class} }
sub filter { shift->{filter} }

sub count {
    my $self = shift;
    return scalar( @{ $self->{list} } );
}

sub next {
    my $self = shift;

    my $record = $self->{list}[$self->{counter}++];
    return undef unless $record;

    my $hit = Oryx::Search::Hit->new(
        record => $record,
        class  => $self->{class},
    );

    if ( $self->{filter} ) {
        if ( $self->{filter}->accept( $hit ) ) {
            return $hit;
        } elsif ( my $next = $self->next() ) {
            return $next;
        }
    } else {
        return $hit;
    }

    return undef;
}

sub hits { 
    my $self = shift;
    $self->{hits} ||= do {
        my @hits;
        while ( my $hit = $self->next() ) {
            push @hits, $hit;
        }
        \@hits;
    };
    wantarray ? @{ $self->{hits} } : $self->{hits};
}

sub reset { shift->{counter} = 0 }

1;
