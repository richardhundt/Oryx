package Oryx::Object;

use strict;

use Carp qw/carp croak confess/;
use Oryx::Search::Searcher;

use overload
    '0+'  => \&oid,
    'cmp' => \&str_cmp,
    '<=>' => \&num_cmp,
    'bool' => sub { $_[0]->{_record} },
    fallback => 1;

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my ( $name ) = ( $AUTOLOAD =~ /([^:]+)$/ );

    my $meta = $self->meta;
    if ( $meta->valid->{ $name } ) {
        if (@_) {
            $self->record->{ $name } = shift;
        } else {
            return $self->record->{ $name };
        }
    }
    elsif ( $meta->assoc( $name ) ) {
        my $relat = $self->related( $name );
        if (@_) {
            $relat->store(@_);
        } else {
            return $self->related( $name );
        }
    } else {
        confess( qq{Can't locate object method "$name" via package "}
            .( ref( $self ) ? ref( $self ) : $self )
        .'"' );
    }
}

sub str_cmp {
    my ( $self, $other ) = @_;
    if ( UNIVERSAL::can( $other, 'oid' ) ) {
        return $self->oid cmp $other->oid;
    } else {
        return $self->oid cmp $other;
    }
}

sub num_cmp {
    my ( $self, $other ) = @_;
    if ( UNIVERSAL::can( $other, 'oid' ) ) {
        return $self->oid <=> $other->oid;
    } else {
        return $self->oid <=> $other;
    }
}

sub new {
    my $class = shift;
    my $proto;
    if ( @_ == 1 and not ref $_[0] ) {
        $proto = { id => $_[0] };
    } else {
        $proto = ref $_[0] ? $_[0] : {@_};
    }

    my $self = bless {
        _record => $proto,
        _assocs => { },
    }, $class;

    $self;
}

*id = \&oid;
sub oid {
    my $self = shift;
    $self->{_record}{ $self->meta->key };
}

sub record { shift->{_record} }

sub load {
    my ( $self ) = @_;
    my $meta = $self->meta;

    my $query = $meta->query;
    my $table = $meta->table;
    my $key = $meta->key;
    my $oid = $self->oid;

    my $colms;
    if ( $meta->abstract ) {
        $colms = [ '*' ];
    } else {
        $colms = [ $meta->columns ];
    }
    my %where = ( $key => $oid );
    my ( $stmt, @bind ) = $query->select( $table, $colms, \%where );

    my $list = $meta->storage->list( $stmt, undef, @bind );
    $self->init( @$list );
}

sub init {
    my ( $self, $record ) = @_;
    if ( defined $record ) {
        $self->{_record} = $record;
    }
    return undef unless defined $self->{_record};
    if ( $self->meta->abstract ) {
        bless $self, $record->{oryx_isa};
    }

    $_->load( $self ) for values %{ $self->meta->fields };
    $self;    
}

sub save {
    my ( $self ) = @_;
    unless ( defined $self->oid ) {
        $self->insert();
    } else {
        $self->load unless $self->lock_version;
        $self->update();
    }
    $self;
}

sub fetch {
    my $class = shift;
    my $object;
    if ( @_ == 1 ) {
        my $key = $class->meta->key;
        $object = $class->new( $key => $_[0] );
    } else {
        $object = $class->new( @_ );
    }
    $object->load();
}

sub fetch_all {
    my $class = shift;
    my $order;
    if ( @_ ) {
        if ( @_ == 1 and ref $_[0] eq 'ARRAY' ) {
            $order = $_[0];
        } else {
            $order = [ @_ ];
        }
    }
    my $meta  = $class->meta;
    my $query = $meta->query;
    my $table = $meta->table;

    my @colms = $meta->columns;
    my ( $stmt, @bind ) = $query->select( $table, \@colms, undef, $order );
    my $list = $meta->storage->list( $stmt, undef, @bind );
    my @objs;
    for my $record ( @$list ) {
        push @objs, $class->new->init( $record );
    }
    wantarray ? @objs : \@objs;
}

sub find {
    my $class = shift;

    my ( $where, $order );
    if ( @_ == 2 and ref $_[0] eq 'HASH' and ref $_[1] eq 'ARRAY' ) {
        ( $where, $order ) = @_;
    } elsif ( @_ == 1 and ref $_[0] eq 'HASH' ) {
        $where = $_[0];
    } else {
        $where = { @_};
    }

    my $meta  = $class->meta;
    my $query = $meta->query;
    my $table = $meta->table;

    my @colms = $meta->columns;
    my ( $stmt, @bind ) = $query->select( $table, \@colms, $where, $order );
    my $list = $meta->storage->list( $stmt, undef, @bind );

    my @objs;
    for my $record ( @$list ) {
        push @objs, $class->new->init( $record );
    }

    wantarray ? @objs : $objs[0];
}

sub search {
    my $class = shift;
    my $param = ref $_[0] ? shift : {@_};
    my $searcher = Oryx::Search::Searcher->new(
        class => $class,
    );
    my $hits = $searcher->search(
        query  => $param->{query},
        filter => $param->{filter},
    );
    return $hits;
}

sub insert {
    my ( $self ) = @_;

    my $meta = $self->meta;
    my $storage = $meta->storage;

    my $query = $meta->query;
    my $table = $meta->table;
    my @colms = $meta->columns;

    $storage->begin;
    eval {
        my $oid = $storage->nextval( $table );
        $self->record->{ $self->meta->key } = $oid;

        # increment our version - die and rollback otherwise
        $self->incr_version();

        # only saves assocs which have been accessed because we're
        # not looking at $meta, and related() does lazy binding.
        $_->save( $self ) for values %{ $self->{_assocs} };

        my $key = $meta->key;
        my ( $stmt, @bind, %data );
        # insert
        $self->record->{ $key } = $oid;
        $_->save( $self ) for values %{ $meta->fields };

        @data{ @colms } = @{ $self->record }{ @colms };
        if ( $meta->base && $meta->base->meta->abstract ) {
            $data{oryx_isa} = $meta->name;
        }

        ( $stmt, @bind ) = $query->insert( $table, \%data );
        $storage->exec( $stmt, undef, @bind );
    };
    if ($@) {
        $storage->rollback();
        die $@;
    } else {
        $storage->commit();
    }
}

sub update {
    my ( $self ) = @_;

    my $meta = $self->meta;
    my $storage = $meta->storage;

    my $query = $meta->query;
    my $table = $meta->table;
    my @colms = $meta->columns;

    $storage->begin;
    eval {
        # increment our version - die and rollback otherwise
        $self->incr_version();

        # only saves assocs which have been accessed because we're
        # not looking at $meta, and related() does lazy binding.
        $_->save( $self ) for values %{ $self->{_assocs} };

        my $key = $meta->key;

        my ( $stmt, @bind, %data );
        my %where = ( $key => $self->oid );
        $_->save( $self ) for values %{ $meta->fields };
        @data{ @colms } = @{ $self->record }{ @colms };

        ( $stmt, @bind ) = $query->update( $table, \%data, \%where );
        $storage->exec( $stmt, undef, @bind );
    };
    if ( $@ ) {
        $storage->rollback();
        die $@;
    } else {
        $storage->commit;
    }
}

sub delete {
    my ( $self ) = @_;
    my $meta = $self->meta;

    my $query = $meta->query;
    my $table = $meta->table;

    $_->delete( $self ) for values %{ $meta->fields };
    $_->delete( $self ) for values %{ $meta->assocs };

    my %where = ( $meta->key() => $self->oid() );
    my ( $stmt, @bind ) = $query->delete( $table, \%where );
    $meta->storage->exec( $stmt, undef, @bind );

    %$self = ( );
    bless( $self, 'Oryx::DeadBeef' );
}

sub related {
    my ( $self, $name ) = @_;
    $self->{_assocs}{$name} ||= do {
        $self->meta->assoc( $name )->bind( $self );
    }
}

sub touch {
    my $self = shift;
    $self->load();
    $self->save();
}

sub incr_version {
    my $self = shift;
    if ( defined $self->oid ) {
        $self->assert_lock_version;
    }
    ++$self->record->{lock_version};
}

sub lock {
    my $self = shift;
    my $meta = $self->meta;
    my $t = $meta->table;
    my $k = $meta->key;
    my $q = "UPDATE $t SET lock_version=(lock_version+1) WHERE $k=?";
    $meta->storage->begin();
    eval { $meta->storage->exec( $q, undef, $self->oid ) };
    if ($@) {
        $self->{_locked} = 0;
        return 0;
    }
    $self->record->{lock_version}++;
    $self->{_locked} = 1;
}

sub unlock {
    my $self = shift;
    my $meta = $self->meta;
    eval { $meta->storage->commit() };
    if ($@) {
        my $error = $@;
        eval { $meta->storage->rollback() };
        $self->record->{lock_version}--;
        $self->{_locked} = 0;
        die $error;
    }
    $self->{_locked} = 0;
}

sub locked { shift->{_locked} }

sub assert_lock_version {
    my ( $self ) = @_;
    my $meta = $self->meta;
    my $rec  = $meta->storage->list(
        "SELECT lock_version FROM ${\$meta->table} WHERE ${\$meta->key}=?",
        undef, $self->oid,
    );
    no warnings 'uninitialized';
    unless ( $rec->[0]->{lock_version} eq $self->lock_version ) {
        die Oryx::Error::StaleObject->new( $meta->name." [${\$self->oid}]", 1 );
    }
}

sub DESTROY { }

1;

