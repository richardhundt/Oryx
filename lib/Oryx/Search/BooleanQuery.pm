package Oryx::Search::BooleanQuery;

use strict;
use warnings;

use Carp qw/croak/;
use UNIVERSAL qw/isa/;

use base qw/Oryx::Search::Query/;

sub new {
    my $class = shift;

    my $self = bless {
        clauses => [ ],
    }, $class;

    return $self;
}

sub prepare {
    my ( $self, $searcher ) = @_;
    foreach my $clause ( @{ $self->{clauses} } ) {
        $clause->{query}->prepare( $searcher );
    }
    $self->{table} = $searcher->table;
}

sub add_clause {
    my ( $self, %clause ) = @_;
    $clause{query} || croak( 'add_clause needs a query object' );
    $clause{occur} ||= 'SHOULD';
    unless ( $clause{occur} =~ /^(?:MUST|MUST_NOT|SHOULD)$/o ) {
        croak( 'unhandled occurrence type: '.$clause{occur} );
    }
    unless ( isa( $clause{query}, 'Oryx::Search::Query' ) ) {
        croak( 'invalid query object: `'.$clause{query}."'" );
    }
    push @{ $self->{clauses} }, \%clause;
}

sub where {
    my $self = shift;

    my @words;
    my $where = '';
    my ( $iter, $oper, $frag, @bind );
    foreach my $clause ( @{ $self->{clauses} } ) {
        ( $frag, @bind ) = $clause->{query}->where;
        push @words, @bind;
        if ( $clause->{occur} eq 'MUST' ) {
            $oper = "AND";
        }
        elsif ( $clause->{occur} eq 'MUST_NOT' ) {
            $oper = "AND NOT";
        }
        else { # SHOULD
            $oper = "OR";
        }
        if ( $oper eq 'OR' ) {
            $oper = '' unless $iter++;
            $where .= " $oper ($frag)";
        } else {
            if ( $iter++ ) {
                $where .= " $oper oid IN (SELECT oid FROM $self->{table} WHERE $frag)";
            } else {
                $where .= " oid IN (SELECT oid FROM $self->{table} WHERE $frag)";
            }
        }
    }
    return ( $where, @words ) ;
}

1;
