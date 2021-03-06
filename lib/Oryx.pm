package Oryx;
use strict;
use DBI;
our $VERSION = '0.50';
1;

__END__

=head1 NAME

Oryx - Agile Object Data Persistence

=head1 SYNOPSIS

 # create a schema
 package My::Schema;
  
 use base qw/Oryx::Schema/;
  
 __PACKAGE__->define(
    'My::Person' => {
        fields => [
            address_1 => [ 'string', size => 63 ],
            address_2 => [ 'string', size => 63 ],
            firstname => [ 'string', size => 31 ],
        ],
    },
  
    'My::User' => {
        base => 'My::Person',
        fields => [
            lastname  => [ 'string', size => 31 ],
            username  => [ 'string', size => 31 ],
        ],
        assocs => [
            notes => [ hash => [ 'string', size => 255 ], compos => 1 ],
        ],
    },
 );
  
 # your application code
 use Oryx::Storage;
  
 my $storage = Oryx::Storage->new(
    dsn => 'dbi:mysql:dbname=test',
    username => 'test',
    password => 'test',
 );
  
 $storage->open( 'My::Schema' );
 $storage->deploy;

 my $user = My::Person->new( $oid );
  
 $user->load();
 $user->firstname( 'Homer' );
 $user->lastname( 'Simpson' );
 $user->notes->{drinks} = "Beer";
 $user->save();

=head1 NOTICE

This is a complete rewrite of Oryx and neither the API nor the schema
generated is compatible with earlier versions. Previous releases had
several features which have turned out to be unused, as well as a few
concurrency issues which made it unsafe. To reflect this, the version
number has been bumped to 0.50.  However, this version of Oryx is still
to be considered an early beta.

=head1 DESCRIPTION

Oryx is an Object Relational Mapper for Perl. It aims for ease of use
and rapid prototyping, with a few important differences to the others
you may find. In particular, Oryx supports native Perl hash and array
associations, both "optimistic locking" using object versioning, and
"pessimistic locking", and ships with a simple database agnostic full
text search capability based on an inverted search index. It also
supports abstract classes, inheritance and manages the database
schema automatically.

=head2 Features in Brief

=over 4

=item Automatic Database Schema Management

With Oryx you need never create a database table by hand nor add a
column to tables when your persistent classes, and therefore your schema
changes. All you need to do is to declare a new class, or add a new field
to an existing one and call C<< $storage->deploy() >>. However, Oryx makes
every effort to keep the generated schema as human readable as possible,
by using natural language inflection on both tables and column names,
including link tables. This means that if you need to query the database
by hand, or fit another ORM to the schema, then you can do that easily.

=item Native Array and Hash Associations

Oryx lets you think about associations between objects as you would with
ordinary. You can say things like: an instance of class B<A> keeps a hash
of instances of class B, and when you access the association, then what
you get is an hash reference. Persistent classes also have the concepts of
"aggregation" and "composition", as in UML. This translates to whether
object deletions and updates cascade (composition) or not (aggregation).

Internally Oryx may use link tables for tracking hash keys and array
indicies, so that most of the time you don't need to think about it.

This gives you an object persistence framework with an object model
which is closer to Perl's than simply thinking about one-to-many
or many-to-one relations.

There are, of course, variations on whether an array association,
for example, is implemented using a link table (L<Oryx::Schema::Array>)
or not (L<Oryx::Schema::IntrArray>).

=item Full Text Indexing and Query Engine

Oryx ships with a simple inverted index search and indexing built in
which allows you to add fast full text searching to your objects. This
is portable accross all databases and supports stopalizing, stemming
and complex boolean query construction, incremental indexing, range
searching and filters.

=item Data Integrity

Oryx maintains data integrity by versioning each object and using an
"Optimistic Locking" strategy during updates and deletes. This means that
during these operations Oryx checks the version of each record it has in
memory against that which is in the database and if a version mismatch
is found, an exception is raised, and the transaction rolled back.

Transactions are short lived and it is "optimistic" because of the
assumption that the common case will succeed so the scope of a transaction
is limited to two queries executed in quick succession; one to fetch
the version of the row and one to perform the update or delete.

Oryx also supports "Pessimistic Locking" allowing you to explicitly
lock an object while you're working with it. Although useful in
certain circumstances, care should be taken with this kind of locking,
particularly in a web based environment, since it can limit concurrency.

=item Inheritance

Oryx implements inheritance using the "Single Table Inheritance" model.
This means that all your classes in the inheritance chain actually store
their data in the same table, but simply add extra columns as they are
specialised. Previous versions of Oryx used multiple tables and thereby
supported multiple inheritance, but it was found that the performance
cost outweighed the benefits of having MI. So the Single Table model
trades disk space for speed.

=item Introspection

A comprehensive meta-model drives Oryx - classes are completely self
aware and expose their meta-data: fields, their type, associations
with other classes, link tables created, etc. This information can be
useful for dynamically creating user interfaces (HTML forms, etc.), for
example, and is accessible via C<< $object->meta >>. You can even change this
information at runtime, perhaps for mocking, or temporarily disabling
parts of a schema.

=item Polymorphic Retrieval

Oryx supports polymorphic retrieval through the use of schema classes
marked as abstract. Concrete classes inheriting from abstract classes
can then be mixed in associations.

For example, say you wanted to store an XHTML document which defined
several different classes for different elements, each with a different
set of allowed attributes and child nodes. You could create an abstract
"Node" class which had an array association called "child_nodes" with
itself. The "Node" class would then be subclassed into different node
types, one for each XHTML element, so that the array of children from a
node can then be a mixture of different types, instead of a homogeneous
list.

=item Usable with Distributed or Asynchronous Systems

One of the problems with using L<DBI> with single-threaded asynchronous
systems (such as L<POE>, L<Event> or L<Coro>) is that database operations
are blocking. One way in which one might try to solve this, is to C<fork>
a child process and run a database proxy in the child.

Oryx makes this easier by using only two methods supported by L<DBI>,
namely C<< $dbh->do(...) >> and C<< $dbh->selectall_arrayref(...) >> as these
don't require the use of an intermediate statement handle. The database
handle object then remains in the child process, and only the queries
and data move back and forth between parent and child.

This is not restricted to forking a child process, of course, but also
allows the creation of a simple database proxy client/server pair where,
using any serialization strategy, queries can be sent over a socket and
records can be returned without needing to resort to writing or using
complicated, specialized database proxy drivers.

=back

=head1 THE SCHEMA

In order to persist your classes, you must first define a schema for
them. This is done by creating a subclass of L<Oryx::Schema>, and then
implementing a a method called C<define(...)> which returns a hash list
of class names to their individual schemas:

 package My::Schema;
 use base qw/Oryx::Schema/;
 
 __PACKAGE__->define(
    'My::Class' => {
        fields => [
            ...
        ],
        assocs => [
            ...
        ]
    },
    ...
 );
 
 1;

The package C<My::Schema> is then passed to C<< $storage->open(...) >>
and assembled into a set of Perl classes ready for use.

 my $storage = Oryx::Storage->new( @conn );
 $storage->open( 'My::Schema' );
 $storage->deploy(); # if the schema is new or has changed

Let us take a look at a more complete example, which illustrates a few
more interesting aspects of Oryx schemas:

 __PACKAGE__->define(
    'My::Person' => {
        fields => [
            address_1 => [ 'string', size => 63 ],
            address_2 => [ 'string', size => 63 ],
            firstname => [ 'string', size => 31 ],
        ],
    },
  
    'My::User' => {
        base => 'My::Person',
        fields => [
            lastname  => [ 'string', size => 31 ],
            username  => [ 'string', size => 31 ],
        ],
        assocs => [
            notes => [ hash => [ 'string', size => 255 ], compos => 1 ],
        ],
    },
 );

This produces the following database schema for MySQL:
 
 CREATE TABLE `people` (
   `id` int(11) NOT NULL default '0',
   `lastname` varchar(31) default NULL,
   `username` varchar(31) default NULL,
   `firstname` varchar(31) default NULL,
   `address_2` varchar(63) default NULL,
   `address_1` varchar(63) default NULL,
   `lock_version` int(11) default NULL,
   PRIMARY KEY  (`id`)
 );
 
 CREATE TABLE `user_notes` (
   `user_id` int(11) NOT NULL default '0',
   `hash_key` varchar(255) NOT NULL default '',
   `note` varchar(255) default NULL,
   PRIMARY KEY  (`user_id`,`hash_key`)
 );

Looking at the schema above, we see that although we have two classes
C<My::Person> and L<My::User>, both are stored in the same table:
C<people>, which has been pluralized correctly.  The latter inherits
from the former as declared by C<< base => 'My::Person' >>. Each class in
an inheritance chain knows which fields it needs, so only those fields
will be selected and visible to the instance.

We then have another table: C<user_notes>. This table represents the
notes hash associated with instances of C<My::User>, and is named to
reflect the fact that it is a one-to-many association.

This table also shows a denormalization which was used to optimize
the schema. In the fragment:

 ...
 assocs => [
     notes => [ hash => [ 'string', size => 255 ], compos => 1 ],
 ],
 ...

we have said that the value type of the hash association is a string, as
opposed to a class (see below). Oryx keeps the values for associations to
simple scalars inside what would otherwise be a link table. If, instead,
we had said:

 ...
 assocs => [
     notes => [ hash => [ 'ref' => 'My::Note' ], compos => 1 ],
 ],
 ...

then the (relevant parts of) C<user_notes> table would read:
 
 CREATE TABLE `user_notes` (
   ...
   `note_id` int(11) default NULL,
   ...
 );

and an appropriate C<My::Note> class and C<notes> table would need to
be defined and created, respectively. This would make C<user_notes> a
"proper" link table. This sort of denormalization is useful in situations
where you know you will only ever need scalar values in the association,
and can therefore save a JOIN operation when retrieving the data.

=head3 Making C<use My::Class;> Work

The symbol tables for persistent classes using the above method will be
constructed at run-time. This means that it doesn't make sense to then
try to C<use My::Class;> somewhere in your code since Perl will fail to
find the corresponding My/Class.pm file, and raise an exception.

One way around this is to put the definition inside a C<BEGIN { ... }>
block to ensure that the classes are available at compile time:

 BEGIN {
     __PACKAGE__->define(
        'My::Class' => {
            fields => [
                ...
            ],
            assocs => [
                ...
            ]
        },
        ...
     );
 } 

and then in another piece of code:

 use My::Schema;
 use My::Class;
 ...

This works because Oryx tweaks C<%INC> in such a way that Perl thinks
the module is already loaded (the BEGIN block doesn't trigger this
behaviour, but the C<%INC> tweak only works if done at compile time).

Another, preferred way, is to create the My/Class.pm module:

 package My::Class;
 use base qw/Oryx::Object/;
 1;

This has the added benefit of allowing for evolutionary programming
in that when you need to extend the class beyond what is supported
by L<Oryx::Object>, then the file already exists so you then just add
your methods to it.

The meta-data needed to persist this class, however, is still kept
centrally inside the C<My::Schema> package.

=head2 Class Definitions

Schema class definitions, as mentioned, are a hash-list keyed on the
name of the class, with a hash reference holding the meta-data required
by Oryx. This meta-data hash reference supports four key-value pairs:

=over 4

=item base

The name of the parent class, if any, as a string. The parent class
does not need to be declared earlier (the outer structure is a hash,
so ordering is undefined anyway).

=item abstract

A flag which, if present, specifies that this is an abstract class. Such
classes are never instantiated directly upon retrieval, but are always
"down cast" to a concrete subclass.

To do this, the table in which these are stored has a field for storing
the class name of the concrete subclass. The object retrieved is then
blessed into this subclass.

=item fields

An array reference of pairs, semantically similar to a hash reference,
except that ordering is preserved (this is useful for auto-generating
user interface components from meta data where it is desirable to impose
ordering on the fields).

Every even element is a string, the name of which is taken to be the
field name, and every corresponding odd element is taken to contain
type information about the field, usually stored in an array reference.
See L</Fields> below for details.

=item assocs

An array reference of association name/type pairs, similiar to fields
above. The type is also an array reference containing a description of
the association type. See L</Associations> below for details.

=back

When the schema is loaded, Oryx creates Perl packages dynamically and
the resulting classes are based on L<Oryx::Object>. Oryx does this by
pushing L<Oryx::Object> to the C<@INC> array of the dynamically created
package. Therefore, all instances of your persistent classes will
respond to the L<Oryx::Object> interface.

So the persistent class dynamically constructed from the schema definition
for that class is conceptually equivalent to saying:

 package My::Class;
 use base qw/Oryx::Object/;
 
 sub meta {
     my $self = shift;
     $self->{_meta} ||= Oryx::Schema::Meta->new(
        name   => __PACKAGE__,
        base   => ...,
        fields => { ... },
        assocs => { ... },
     );
 }

however, Oryx takes care of the C<meta> accessor for you (it's actually
inheritable class data). So in a sense, C<meta> returns the class
instance, which is meta-data to the persistent object instances.

=head3 Fields

Fields declared in classes map to columns in tables of the database
schema. Each field is a pair; the name and an array reference expressing
its type. The type array reference has the type name as its first
element followed by parameters.

The C<required> parameter is common to all fields and is optional,
as is the C<default> parameter, which allows one to specify a default
value for the field.

The following example declares a field (or column) named C<cheese>
to be of type C<string> (VARCHAR), with a maximum length of 127, is
required (NOT NULL) and defaults to "cheddar":

 fields => [
     ...
     cheese => [ 'string', size => 127, required => 1, default => 'cheddar' ],
     ...
 ],

Besides mapping field types to their underlying SQL column types, Oryx
also allows fields to run hooks during storage and retrieval operations.
More complex fields such as C<email> or C<file> use this to do pattern
matching during storage, and creating a file handle during retrieval
respectively. If while saving Oryx detects an invalid value for a field,
then a validation error will be raised.

The following is a complete list of currently supported fields with
their signatures (if any), and mappings to MySQL column types:

=over 4

=item L<Oryx::Schema::Field::Oid> : INT

Used internally to represent the primary key.

=item L<Oryx::Schema::Field::String> : VARCHAR

Creates a field of size C<$size> for holding character data. If C<$size>
is not supplied then it defaults to 255:

 field_name => [ 'string', size => $size ]

=item L<Oryx::Schema::Field::Integer> : INT

Creates an integer field of size C<$size>. If C<$size> is not supplied
the it defaults to 11:

 field_name => [ 'integer', size => $size ]

=item L<Oryx::Schema::Field::Boolean> : TINYINT

Creates a boolean field. The value zero is false. As with Perl, any
other value is true:

 field_name => [ 'boolean' ]

=item L<Oryx::Schema::Field::Text> : TEXT

Creates a text field for holding longer text data:

 field_name => [ 'text' ]

=item L<Oryx::Schema::Field::Float> : FLOAT

Creates a field for holding floating point (real) numbers:

 field_name => [ 'float' ]

=item L<Oryx::Schema::Field::Binary> : BLOB

Creates a field for holding binary data:

 field_name => [ 'binary' ]

=item L<Oryx::Schema::Field::Email> : VARCHAR

Creates a field for holding email adresses. The constraint is applied
as the record is saved to the database by requiring the value to match
against the following pattern:

 qr/^[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,4}$/i

 field_name => [ 'email' ]

=item L<Oryx::Schema::Field::Url> : VARCHAR

Creates a field for holding URI's. The constraint is applied as the
record is saved to the database by requiring the value to match
against the following pattern (borrowed from L<URI>):

 qr|^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?$|

 field_name => [ 'url' ]

When the record is retrieved, the value is turned into a L<URI> object.

=item L<Oryx::Schema::Field::Password> : VARCHAR

Creates a field for storing passwords. The password is encrypted before
being saved to the database. The value of this field type overloads the
string comparison operator (`cmp') so that a string can be compared to
the encrypted value in memory:

 field_name => [ 'password' ]

=item L<Oryx::Schema::Field::Enum> : VARCHAR

Creates an enumerated field. The value is checked against the list of
acceptable values when the record is saved to the database and an error
is raised if it is not one of them:

 field_name => [ 'enum', items => [ 'one', 'two', 'three' ] ]

=item L<Oryx::Schema::Field::File> : VARCHAR

Creates a field for storing files. The file data is not saved in the
database but under an auto-generated file name under the directory
specified with the C<base> parameter of the form: base/table/field_name.id

 field_name => [ 'file', base => '/some/path' ]

The field value must be an instance of L<IO::File>, and this is what
will be created for you when the object is later retrieved.

=item L<Oryx::Schema::Field::Date> : DATE

Creates a field for storing dates. The date value is formatted with
L<Date::Format> using the default format: '%Y-%m-%d' when stored to
the database:

 field_name => [ 'date', format => $format ]

The format can be overridden by specifying the C<format> parameter.

=item L<Oryx::Schema::Field::Time> : TIME

Creates a field for storing time values. The time value is formatted
with L<Date::Format> using the default format: '%H:%M:%S' when stored
to the database:

 field_name => [ 'time', format => $format ]

The format can be overridden by specifying the C<format> parameter.

=item L<Oryx::Schema::Field::DateTime> : DATETIME

Creates a field for storing date-time values. The value is formatted
with L<Date::Format> using the default format: '%Y-%m-%d %H:%M:%S'
when stored to the database:

 field_name => [ 'datetime', format => $format ]

The format can be overridden by specifying the C<format> parameter.

=item L<Oryx::Schema::Field::Range> : INT or FLOAT 

Creates a field for storing numbers constrained to be within a given
range:

 field_name => [ 'range', min => $min, max => $max, step => $step ]

The C<min> and C<max> parameters specify the lower and upper boundaries of
the range (inclusive), and the C<step> specifies a multiplier for discrete
values. If C<step> is a floating point number, then the column type will
be mapped to FLOAT, otherwise to INT (in MySQL, other databases may vary).

=item L<Oryx::Schema::Field::Complex>

Creates a field for storing complex data structures which are serialized
using L<JSON>:

 field_name => [ 'complex' ]

Please note that the caveats of L<JSON> apply, specifically that cyclic
data structures are not supported. Alternative serialization strategies
may be supported in future.

=back

=head3 Associations

Just as associations between Perl objects are realised as plain, Array
or Hash references, so too are Oryx associations realised.

However, there is more than one way of mapping each of these to a
relational database, depending mainly on whether back-references are
needed, and whether an intermediate link table is created or not.

There are, for example, two types of Hash and Array associations;
a non-intrusive form (L<Oryx::Schema::Array>, which creates a link
table but doesn't support back references, and an intrusive form
(L<Oryx::Schema::IntrArray) which doesn't create a link table but does
support back references ("intrusive" because it adds a field to the
target table for keeping references).

Associations are also declared using name and array reference pairs,
and are added in much the same way as fields are, for instance:

 'My::Article' => {
     fields => [ ... ],
     assocs => [
         author => [ 'ref' => 'My::User' ]
     ],
 },

declares that a C<My::Article> instance holds a reference to a C<My::User>
instance.

Oryx currently supports the following types of associations:

=over 4

=item L<Oryx::Schema::Ref>

Keeps a foreign key in the current class which references another class.

=item L<Oryx::Schema::Hash>

Creates a link table as with many-to-many relations, but with an added
column for keeping hash keys which are used to construct a hash reference
for the relation. Also supports flat values (in which case it's not really
a link table).

=item L<Oryx::Schema::Array>

Like L<Oryx::Schema::Hash>, but constructs an array ref for the association
and keeps the array indicies. Also supports flat values.

=item L<Oryx::Schema::List>

An unordered list association like the classic one-to-many where the other
class keeps a foreign key to us. No link tables are created as this intrudes
into the other class by adding a column which keeps our primary key.

=item L<Oryx::Schema::IntrHash>

Like L<Oryx::Schema::List> in that it doesn't create a link table, but
presents the same interface as L<Oryx::Schema::Hash>. An extra column
is created in the other table which holds the hash key.

=item L<Oryx::Schema::IntrArray>

Like L<Oryx::Schema::IntrHash>, but for array associations. An intrusive
column is created in the other class which holds the array index.

=back

=head3 Inheritance

Oryx gives you single inheritance using a single table to store all classes
in the inheritance chain. To extend a class, we can do the following:

 my $users = schema->class('My::Users');
 $users->base('My::Person');
 $users->fields(
    firstname => schema->string(),
    lastname  => schema->string(),
 );

Here your C<My::User> instances will be stored in the "people" table with
two columns "firstname", and "lastname" added to that table. The classes
will only extract and store columns which they know about, so you won't
get fields from other subclasses polluting your objects.

=head2 Example Schema

The following is a complete schema example (taken from the tests):

 package Test::Schema;
 
 use strict;
 
 use base qw/Oryx::Schema/;
 
 __PACKAGE__->define(
     'My::User' => {
         base => 'My::Person',
         fields => [
             lastname  => [ string => size => 32 ],
             username  => [ string => size => 32 ],
             form_data => [ 'complex' ],
         ],
         assocs => [
             articles => [ list => 'My::Article', compos => 1 ],
             notes    => [ hash => [ 'string', size => 255 ], compos => 1 ],
         ],
     },
 
     'My::Person' => {
         fields => [
             address_1 => [ 'string', size => 127  ],
             address_2 => [ 'string', size => 127  ],
             firstname => [ 'string', size => 32   ],
         ],
         assocs => [
             login => [ 'ref' => 'My::Login', compos => 1 ],
         ],
     },
 
     'My::Company' => {
         base => 'My::Person',
         fields => [
             status => [ 'string' ],
             email  => [ 'email', required => 1 ],
         ],
     },
 
     'My::Login' => {
         fields => [
             usname => [ 'string',   size => 32 ],
             passwd => [ 'password', size => 32 ],
         ]
     },
 
     'My::Article' => {
         fields => [
             title   => [ 'string', search => 1, weight => 0.5, size => 31 ],
             summary => [ 'text',   search => 1, weight => 0.2 ],
             rating  => [ 'range', min => 0, max => 100 ],
             status  => [ 'enum', items => [qw/ published working deleted /] ],
         ],
         assocs => [
             chapters => [ 'hash', [ 'ref' => 'My::Chapter' ], compos => 1 ],
             author   => [ 'ref' => 'My::User' ],
         ]
     },
 
     'My::Chapter' => {
         fields => [
             title => [ 'string', size => 127 ],
         ],
         assocs => [
             pages => [ array => [ 'ref' => 'My::Page', compos => 1 ] ],
         ]
     },
 
     'My::Page' => {
         fields => [
             title => [ 'string' ],
         ],
         assocs => [
             paragraphs => [ 'array' => [ 'text' ] ],
         ]
     }
 );
 
 1;

=head1 PERSISTENT OBJECTS

Working with persistent objects follows a simple pattern in that the
objects are usually constructed before binding them to data from the
database. For example, the general pattern for creating and storing new
object is:

 my $user = My::User->new( \%fields );
 $user->save();

To retrieve the object again:

 my $user = My::User->new( $oid );
 $user->load();

When a field or an association is accessed, an AUTOLOAD method consults
the meta-data. If the access not valid (i.e. there is no corresponding
field or association defined), then an exception is raised. Otherwise
the object will let you get or set a field value. For example:

 $user->lastname( 'Random' );
 $user->save();

In the case of it being an association, the association is loaded on demand.
For example C<My::Article::chapters> accesses a hash association storing
C<My::Chapter> objects:

 my $article = My::Article->new( title => 'Meta Mania' );
 $article->chapters->{chapter_1} = My::Chapter->new( title => 'Chapter 1' );
 $article->save();

Setting an entry in C<chapters> tracks it as a change and the call to
C<save> persists the all objects in the tree recursively.

