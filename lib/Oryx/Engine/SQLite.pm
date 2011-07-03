package Oryx::Engine::SQLite;

use strict;
use warnings;

use base qw/Oryx::Engine/;

our %SQL_TYPES = (
    'oid'       => 'integer',
    'integer'   => 'integer',
    'string'    => 'text',
    'text'      => 'text',
    'binary'    => 'blob',
    'float'     => 'real',
    'boolean'   => 'integer',
    'date'      => 'text',
    'time'      => 'text',
    'datetime'  => 'text',
);

sub type2sql {
    my ($self, $type, $size) = @_;
    my $sql_type = $SQL_TYPES{$type};
    return $sql_type;
}

# Columns may not be dropped in SQLite. Oh, well.
sub drop_column { }

sub table_exists {
    my ( $self, $table ) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->table_info('%', '%', $table);
    $sth->execute();
    my @rv = @{ $sth->fetchall_arrayref };
    $sth->finish;
    return grep { lc $_->[2] eq lc $table } @rv;
}

sub column_exists {
    my ( $self, $table, $column ) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->table_info('%', '%', $table);
    $sth->execute();

    my @rv = @{ $sth->fetchall_arrayref };
    $sth->finish;

    my ( $ddl ) = pop @{ $rv[$#rv] };
    $ddl =~ /CREATE\s+TABLE\s+$table\s+\(\s*(.+?)\s*\)$/s;
    my %fields = map { split( /\s+/, $_, 2 ) } split( /\s*,\s*/s, $1 );

    return $fields{ $column };
}

1;
