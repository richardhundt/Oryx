package Oryx::Engine;

use strict;
use warnings;

use Carp qw/carp croak confess/;

our $SEQ_TABLE = 'oryx_seq';
our $IDX_TABLE = 'oryx_idx';

sub create {
    my ( $class, $name, $conf ) = @_;
    my $adapter = 'Oryx::Engine::'.$name;
    eval "require $adapter"; die $@ if $@;
    return $adapter->new( config => $conf );
}

sub new {
    my $class = shift;
    if ( $class eq __PACKAGE__ ) {
        croak ( 'usage: Oryx::Engine->create( $driver, $config )' );
    }

    my $param = ref $_[0] ? $_[0] : { @_};
    my $self = bless {
        config => $param->{ config } || croak( 'Need a config' ),
    }, $class;

    return $self;
}

sub dbh {
    my $self = shift;
    undef( $self->{dbh} ) if ( $self->{dbh} and not $self->{dbh}->ping );
    $self->{ dbh } ||= do {
        my $conf = $self->{ config };
        my $pass = ref $conf->{password} ? $conf->{password}->() : $conf->{password};
        my $conn = [ $conf->{dsn}, $conf->{username}, $pass ];
        $self->connect( $conn );
    };
}

sub connect {
    my $self = shift;
    my $conn = ref $_[0] ? $_[0] : [@_];
    my $dbh = DBI->connect( @$conn ) || croak DBI->errstr; 
    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 1;
    $self->{dbh} = $dbh;
    $dbh;
}

sub schema_name {
    my $self = shift;
    $self->{ schema_name } ||= do {
        my $dsn = $self->{ config }{ dsn };
        my ( $name ) = ( $dsn =~ /dbname=(\w+)/ );
        $name;
    };
}

#============================================================================
# TRANSACTIONS
#============================================================================
sub begin {
    my $self = shift;
    $self->{txn_depth}++;
    $self->dbh->{AutoCommit} = 0;
}

sub rollback {
    my $self = shift;
    if ( --$self->{txn_depth} == 0 ) {
        $self->dbh->rollback;
        $self->dbh->{AutoCommit} = 1;
    }
}

sub commit {
    my $self = shift;
    if ( --$self->{txn_depth} == 0 ) {
        $self->dbh->{AutoCommit} = 1;
    }
}

sub atomic {
    my ( $self, $code, $tries ) = @_;
    $tries ||= 1;
    for ( 1 .. $tries ) {
        my @retval = ( );
        $self->begin();
        eval { @retval = &$code };
        if ($@) {
            my $error = $@;
            eval { $self->rollback() };
            if ( UNIVERSAL::isa( $error, 'Oryx::Error' ) ) {
                die $error;
            } else {
                confess( "ROLLBACK - reason: $error" );
            }
        } else {
            $self->commit();
            return @retval;
        }
    }
}

sub type2sql {
    my ($self, $type, $size, $extra) = @_;

    my $class = ref $self;
    no strict 'refs';
    my $sql_type = ${"${class}::TYPE_MAP"}{$type};

    # Append a size if given
    $sql_type .= "($size)" if defined $size;
    $sql_type .= " $extra" if defined $extra;

    return $sql_type;
}

#============================================================================
# DATA DEFINITION
#============================================================================
sub column_exists {
    my ($self, $table, $field) = @_;

    my $dbh = $self->dbh;
    my $esc = $dbh->get_info( 14 );

    $table =~ s/([_%])/$esc$1/g;
    $field =~ s/([_%])/$esc$1/g;

    my $sth = $dbh->column_info('%', '%', $table, $field);

    $sth->execute();
    my @rv = @{ $sth->fetchall_arrayref };

    $sth->finish;
    return @rv;
}

sub create_column {
    my ($self, $table, $field, $type) = @_;

    my $dbh = $self->dbh;
    my $sth = $dbh->prepare(<<"SQL");
ALTER TABLE $table ADD COLUMN $field $type;
SQL

    $sth->execute;
    $sth->finish;
}

# This works in MySQL and PostgreSQL.
sub drop_column {
    my ($self, $table, $column) = @_;

    my $dbh = $self->dbh;
    my $sth = $dbh->prepare(<<"SQL");
ALTER TABLE $table DROP COLUMN $column;
SQL
    $sth->execute;
    $sth->finish;
}

sub table_exists {
    my ($self, $table) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->table_info('%', '%', $table);
    my $esc = $dbh->get_info( 14 );
    $table  =~ s/([_%])/$esc$1/g;
    $sth->execute();
    my @rv = @{$sth->fetchall_arrayref};
    $sth->finish;
    return @rv;
}
 
sub create_table {
    my ($self, $table, $fields, $types) = @_;

    my $dbh = $self->dbh;
    my $sql = <<"SQL";
CREATE TABLE $table (
SQL

    if ( defined $fields and defined $types ) {
	for ( my $x = 0; $x < @$fields; $x++ ) {
	    $sql .= '  '.$fields->[$x].' '.$types->[$x];
	    $sql .= ($x != $#$fields) ? ",\n" : "\n";
	}
    }

    $sql .= <<SQL;
);
SQL

    my $sth = $dbh->prepare($sql);
    $sth->execute;
    $sth->finish;
}

sub drop_table {
    my ($self, $table) = @_;

    my $dbh = $self->dbh;
    my $sql = "DROP TABLE $table";
    my $sth = $dbh->prepare($sql);

    $sth->execute();
    $sth->finish;
}

#============================================================================
# SEQUENCES
#============================================================================
sub touch_sequence_table {
    my $self = shift;
    unless ( $self->table_exists($SEQ_TABLE) ) {
        my $seq_fields = [ 'name', 'id' ];
        my $seq_types  = [
            $self->type2sql('string', 255), $self->type2sql('integer'),
        ];
	$self->create_table(
            $SEQ_TABLE, $seq_fields, $seq_types
        );
	$self->create_index($SEQ_TABLE, 'name');
    }
}

sub sequence_exists {
    my ($self, $table) = @_;
    $self->touch_sequence_table();

    my $sql = "SELECT * FROM $SEQ_TABLE WHERE name=?";
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare($sql);

    $sth->execute($self->_seq_name($table));
    my @rv = @{ $sth->fetchall_arrayref };
    $sth->finish;
    return @rv;
}

sub create_sequence {
    my ($self, $table) = @_;
    $self->touch_sequence_table();

    my $dbh = $self->dbh;
    my $sql = "INSERT INTO $SEQ_TABLE VALUES ('"
        .$self->_seq_name($table)."', 0)";

    my $sth = $dbh->prepare($sql);

    $sth->execute();
    $sth->finish;
}

sub drop_sequence {
    my ($self, $table) = @_;

    $self->touch_sequence_table();

    my $dbh = $self->dbh;
    my $sql = "DELETE FROM $SEQ_TABLE WHERE name='"
        .$self->_seq_name($table)."'";

    my $sth = $dbh->prepare($sql);

    $sth->execute();
    $sth->finish;
}

sub nextval {
    my ($self, $table) = @_;

    my $dbh = $self->dbh;

    # If the driver doesn't implement a sane nextval then we try
    # to wrap an UPDATE and SELECT on our sequence table in a txn.
    my ( $oid ) = $self->atomic(sub {
        my $sth = $dbh->prepare_cached(
            "UPDATE $SEQ_TABLE SET id=(id + 1) WHERE name=?"
        );
        $sth->execute($self->_seq_name($table));
        $sth->finish;

        $sth = $dbh->prepare_cached(
            "SELECT id FROM $SEQ_TABLE WHERE name=?"
        );
        $sth->execute($self->_seq_name($table));
        my $oid = $sth->fetch->[0];
        $sth->finish;
        return $oid;
    });

    return $oid;
}

sub _seq_name { return $_[1]."_id_seq" }

#============================================================================
# INDICIES
#============================================================================
sub create_index {
    my ($self, $table, @fields) = @_;

    my $list = join(',', @fields );
    my $name = join('_', @fields );
    $self->dbh->do( "CREATE INDEX ".$name."_index ON $table ( $list )" );
}

sub drop_index {

}

sub index_table {
    my $self = shift;
    $self->{index_table} ||= do {
        unless ( $self->table_exists( $IDX_TABLE ) ) {
            my $idx_fields = [ qw/ word class field oid score version / ];
            my @sizes = qw/ 255 255 255 /;
            my @types = qw/ string string string oid float integer /;
            my $idx_types = [
                map { $self->type2sql($types[$_], $sizes[$_]) } 0 .. $#types
            ];
            $self->create_table(
                $IDX_TABLE, $idx_fields, $idx_types
            );
            $self->create_index( $IDX_TABLE, 'class', 'oid', 'version');
            $self->create_index( $IDX_TABLE, 'class', 'word', 'field', 'oid');
            $self->create_index( $IDX_TABLE, 'oid', 'field', 'word');
            $self->create_index( $IDX_TABLE, 'oid', 'score' );
        }
        $IDX_TABLE;
    };
}


1;
