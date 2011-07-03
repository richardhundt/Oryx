package Oryx::Engine::mysql;

use strict;
use warnings;

use base qw/Oryx::Engine/;

our %TYPE_MAP = (
    'oid'       => 'INT',
    'integer'   => 'INT',
    'string'    => 'VARCHAR',
    'text'      => 'TEXT',
    'binary'    => 'BLOB',
    'float'     => 'FLOAT',
    'boolean'   => 'TINYINT',
    'date'      => 'DATE',
    'time'      => 'TIME',
    'datetime'  => 'DATETIME',
);

our $SEQ_TABLE = $Oryx::Engine::SEQ_TABLE;

sub table_exists {
    my ($self, $table) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->table_info('%', $self->schema_name, $table);
    $sth->execute();
    my @rv = @{$sth->fetchall_arrayref};
    $sth->finish;
    return grep { $_->[2] eq $table } @rv;
}
 
sub create_table {
    my ($self, $table, $cols, $types, $pkey) = @_;

    my $dbh = $self->dbh;
    my $sql = <<"SQL";
CREATE TABLE $table (
SQL
    my @ddl;
    if ( defined $cols and defined $types ) {
        @ddl = map { "  ".$cols->[$_]." ".$types->[$_] } 0 .. $#$cols;
    }
    if ( defined $pkey and @$pkey ) {
        push( @ddl, "  PRIMARY KEY (".join( ",", @$pkey ).")\n" );
    }
    $sql .= join( ",\n", @ddl );
    $sql .= <<SQL;
) TYPE=InnoDB;
SQL

    my $sth = $dbh->prepare($sql);
    $sth->execute;
    $sth->finish;
}

sub type2sql {
    my ($self, $type, $size, $extra) = @_;
    my $sql_type = $TYPE_MAP{$type};
    if ( $type eq 'string') {
        $size ||= '255';
        $sql_type .= "($size)";
    }
    $sql_type .= " $extra" if defined $extra;
    return $sql_type;
}

sub column_exists {
    my ($self, $table, $field) = @_;

    my $dbh = $self->dbh;
    my $esc = $dbh->get_info( 14 );

    my $sth = $dbh->column_info(undef, undef, $table, '%');

    $sth->execute();
    my $found = 0;
    while (my $row = $sth->fetchrow_hashref()) {
        if ( lc( $row->{COLUMN_NAME} ) eq lc( $field ) ) {
            $found = 1;
            last;
        }
    }

    $sth->finish;
    return $found;
}

sub nextval {
    my ($self, $table) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare_cached(
        "UPDATE $SEQ_TABLE SET id=LAST_INSERT_ID(id + 1) WHERE name=?"
    );
    $sth->execute($self->_seq_name($table));
    $sth->finish;

    $sth = $dbh->prepare_cached(
        "SELECT LAST_INSERT_ID()"
    );
    $sth->execute();
    my $id = $sth->fetch->[0];

    $sth->finish;
    return $id;
}

1;
