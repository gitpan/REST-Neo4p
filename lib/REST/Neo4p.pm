#$Id: Neo4p.pm 17638 2012-08-30 03:52:17Z jensenma $
package REST::Neo4p;
use strict;
use warnings;
use Carp qw(croak carp);
use REST::Neo4p::Agent;
use REST::Neo4p::Entity;
use REST::Neo4p::Node;
use REST::Neo4p::Relationship;
use REST::Neo4p::Index;
use REST::Neo4p::Query;
use REST::Neo4p::Exceptions;

BEGIN {
  $REST::Neo4p::VERSION = '0.1';
}
our $AGENT;

# connect($host_and_port)
sub connect {
  my $class = shift;
  my ($server_address) = @_;
  REST::Neo4p::LocalException->throw("Server address not set")  unless $server_address;
  $AGENT = REST::Neo4p::Agent->new();
  return 1 if $AGENT->connect($server_address);
  return;
}

# $node = REST::Neo4p->get_node_by_id($id)
sub get_node_by_id {
  my $class = shift;
  my ($id) = @_;
  return REST::Neo4p::Entity->_entity_by_id('node',$id);
}

# $reln = REST::Neo4p->get_relationship_by_id($id);
sub get_relationship_by_id {
  my $class = shift;
  my ($id) = @_;
  return REST::Neo4p::Entity->_entity_by_id('relationship',$id);
}

sub get_index_by_name {
  my $class = shift;
  my ($name) = @_;
  return REST::Neo4p::Entity->_entity_by_id('index',$name);
}

# @all_reln_types = REST::Neo4p->get_relationship_types
sub get_relationship_types {
  my $class = shift;
  REST::Neo4p::CommException->throw('Not connected') unless $AGENT;
  my $decoded_json = $AGENT->get_relationship_types();
  return ref $decoded_json ? @$decoded_json : $decoded_json;
}

sub get_indexes {
  my $class = shift;
  my ($type) = @_;
  REST::Neo4p::CommException->throw('Not connected') unless $AGENT;
  my $decoded_resp = $AGENT->get_data('index',$type);
  my @ret;
  # this rest method returns a hash, not an array (as for relationships)
  for (keys %$decoded_resp) {
    push @ret, REST::Neo4p::Index->new_from_json_response($decoded_resp->{$_});
  }
  return @ret;
}

sub get_node_indexes { shift->get_indexes('node',@_) }
sub get_relationship_indexes { shift->get_indexes('relationship',@_) }

=head1 NAME

REST::Neo4p - Perl object bindings for a Neo4j database

=head1 SYNOPSIS

  use REST::Neo4p;
  REST::Neo4p->connect('http://127.0.0.1:7474');

=head1 DESCRIPTION

C<REST::Neo4p> provides a Perl 5 object framework for accessing and
manipulating a L<Neo4j|http://neo4j.org> graph database server via the
Neo4j REST API. Its goals are

(1) to make the API as transparent as possible, allowing the user to
work exclusively with Perl objects, and

(2) to exploit the API's self-discovery mechanisms, avoiding as much
as possible internal hard-coding of URLs.

Neo4j entities are represented by corresponding classes:

=over

=item *

Nodes : L<REST::Neo4p::Node|REST::Neo4p::Node>

=item *

Relationships : L<REST::Neo4p::Relationship|REST::Neo4p::Relationship>

=item *

Indexes : L<REST::Neo4p::Index|REST::Neo4p::Index>

=back

Actions on class instances have a corresponding effect on the database
(i.e., C<REST::Neo4p> approximates an ORM).

The class L<REST::Neo4p::Query> provides a DBIesqe Cypher query facility.

=head1 CLASS METHODS

=over

=item connect()

 REST::Neo4p->connect( $server )

=item get_node_by_id()

 $node = REST::Neo4p->get_node_by_id( $id );

=item get_relationship_by_id()

 $relationship = REST::Neo4p->get_relationship_by_id( $id );

=item get_index_by_name()

 $index = REST::Neo4p->get_index_by_name( $name );

=item get_relationship_types()

 @all_relationship_types = REST::Neo4p->get_relationship_types;

=item get_indexes(), get_node_indexes(), get_relationship_indexes()

 @all_indexes = REST::Neo4p->get_indexes;
 @node_indexes = REST::Neo4p->get_node_indexes;
 @relationship_indexes = REST::Neo4p->get_relationship_indexes;


=back

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

=cut

1;

