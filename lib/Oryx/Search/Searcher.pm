package Oryx::Search::Searcher;

use strict;
use warnings;

use Oryx::Search::HitList;

sub new {
    my ( $class, %args ) = @_;
    my $self = bless {
        class => $args{class},
    }, $class;
    return $self;
}

sub class { shift->{class} }
sub table { shift->storage->engine->index_table }

sub storage { shift->class->meta->storage }
sub indexer { shift->class->meta->indexer }

sub splitter { shift->indexer->splitter }
sub stemmer  { shift->indexer->stemmer  }

sub search {
    my ( $self, %args ) = @_;

    my $query  = delete $args{query};
    my $filter = delete $args{filter};

    $query->prepare( $self );

    my ( $where, @bind ) = $query->where();

    if ( defined $filter ) {
        $filter->prepare( $self );
        my ( $fwhere, @fbind ) = $filter->where();
        if ( $fwhere ) {
            $where .= " AND $fwhere";
            push @bind, @fbind;
        }
    }

    my $class = $self->class;
    my $index_table = $self->table;
    my $class_table = $class->meta->table;
    my $class_colms = join( ',', $class->meta->columns );

    my $stmt = qq{
        SELECT oid,
            SUM($index_table.score) AS oryx_idx_score,
            COUNT(*) AS oryx_idx_count, $class_colms
        FROM $index_table INNER JOIN $class_table ON oid=id
        WHERE class=? AND ( $where ) 
        GROUP BY oid 
        ORDER BY
            oryx_idx_score DESC,
            oryx_idx_count DESC
    };
    unshift @bind, $class;
    my $list = $self->storage->list( $stmt, undef, @bind );

    my $hits = Oryx::Search::HitList->new(
        list => $list,
        class => $class,
        filter => $filter,
    );
    return $hits;
}

1;
