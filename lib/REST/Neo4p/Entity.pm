#$Id: Entity.pm 17638 2012-08-30 03:52:17Z jensenma $
package REST::Neo4p::Entity;
use REST::Neo4p::Exceptions;
use Carp qw(croak carp);
use JSON;
use strict;
use warnings;

# base class for nodes, relationships, indexes...
BEGIN {
  $REST::Neo4p::Entity::VERSION = '0.1';
}

our $ENTITY_TABLE = {};

# new(\%properties)
# creates an entity in the db (with \%properties set), and returns
# a Perl object

sub new {
  my $class = shift;
  my ($entity_type) = $class =~ /.*::(.*)/;
  $entity_type = lc $entity_type;
  if ($entity_type eq 'entity') {
    REST::Neo4p::NotSuppException->throw("Cannot use ".__PACKAGE__." directly");
  }
  my ($properties) = (@_);
  my $url_components = delete $properties->{_addl_components};
  my $agent = $REST::Neo4p::AGENT;
  unless ($agent) {
    croak "Not connected";
  }
  my $decoded_resp = $agent->post_data([$entity_type,
					$url_components ? @$url_components : ()],
				       $properties);
  unless ($decoded_resp) {
    carp $agent->errmsg;
    return;
  }
  $decoded_resp->{self} ||= $agent->location;
  return $class->new_from_json_response($decoded_resp);
}

sub new_from_json_response {
  my $class = shift;
  my ($entity_type) = $class =~ /.*::(.*)/;
  $entity_type = lc $entity_type;
  if ($entity_type eq 'entity') {
    REST::Neo4p::NotSuppException->("Cannot use ".__PACKAGE__." directly");
  }
  my ($decoded_resp) = (@_);
  unless ($ENTITY_TABLE->{$entity_type}{_actions}) {
    # capture the url suffix patterns for the entity actions:
    for (keys %$decoded_resp) {
      my ($suffix) = $decoded_resp->{$_} =~ m|.*$entity_type/[0-9]+/(.*)|;
      $ENTITY_TABLE->{$entity_type}{_actions}{$_} = $suffix;
    }
  }
  # "template" in next line is a kludge for get_indexes
  my $self_url  = $decoded_resp->{self} || $decoded_resp->{template};
  $self_url =~ s/{key}.*$//; # another kludge for get_indexes
  my ($obj) = $self_url =~ /([0-9]+|[a-z_]+)\/?$/i;
  if (defined $ENTITY_TABLE->{$entity_type}{$obj}) {
    # already have the object
    return $ENTITY_TABLE->{$entity_type}{$obj}{self};
  }
  else {
    # another kludge for get_indexes
    if ($decoded_resp->{template}) {
      ($decoded_resp->{type}) = $decoded_resp->{template} =~ m|index/([a-z]+)/|;
    }
    $ENTITY_TABLE->{$entity_type}{$obj}{entity_type} = $entity_type;
    $ENTITY_TABLE->{$entity_type}{$obj}{self} = \$obj;
    $ENTITY_TABLE->{$entity_type}{$obj}{self_url} = $self_url;
    $ENTITY_TABLE->{$entity_type}{$obj}{type} = $decoded_resp->{type};
    bless \$obj, $class;
  }
}

# remove() - delete the node and destroy the object
sub remove {
  my $self = shift;
  my @url_components = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  $agent->delete_data($entity_type, @url_components, $$self);
  $self->DESTROY;
  return 1;
}
# set_property( { prop1 => $val1, prop2 => $val2, ... } )
# ret true if success, false if fail
sub set_property {
  my $self = shift;
  my ($props) = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  my $suffix = $self->_get_url_suffix('property');
  my @ret;
  $suffix =~ s|/[^/]*$||; # strip the '{key}' placeholder
  for (keys %$props) {
    $agent->put_data([$entity_type,$$self,$suffix,
		      $_], $props->{$_});
  }
  return 1;
}

# @prop_values = get_property( qw(prop1 prop2 ...) )
sub get_property {
  my $self = shift;
  my @props = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  my $suffix = $self->_get_url_suffix('property');
  my @ret;
  $suffix =~ s|/[^/]*$||; # strip the '{key}' placeholder
  for (@props) {
    my $decoded_resp = $agent->get_data($entity_type,$$self,$suffix,$_);
    push @ret, $decoded_resp;
  }
  return @ret == 1 ? $ret[0] : @ret;
}

# $prop_hash = get_properties()
sub get_properties {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  my $suffix = $self->_get_url_suffix('property');
  $suffix =~ s|/[^/]*$||; # strip the '{key}' placeholder
  my $decoded_resp = $agent->get_data($entity_type,$$self,$suffix);
  return $decoded_resp;
  
}
# remove_property( qw(prop1 prop2 ...) )
sub remove_property {
  my $self = shift;
  my @props = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  my $suffix = $self->_get_url_suffix('property');
  foreach (@props) {
    $agent->delete_data($entity_type,$$self,$suffix,$_);
  }
  return 1;
}

sub id { ${$_[0]} }

sub entity_type { shift->_entry->{entity_type} }

# $obj = REST::Neo4p::Entity->_entity_by_id($entity_type, $id) or
# $node_obj = REST::Neo4p::Node->_entity_by_id($id);
# $relationship_obj = REST::Neo4p::Relationship->_entity_by_id($id)
sub _entity_by_id {
  my $class = shift;
  if (ref $class) {
    carp "_entity_by_id is a class method only";
    return;
  }
  my $entity_type = $class;
  my $id;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  if ($entity_type eq 'entity') {
    ($entity_type,$id) = @_;
  }
  else {
    ($id) = @_;
  }
  return $ENTITY_TABLE->{$entity_type}{$id} && 
    $ENTITY_TABLE->{$entity_type}{$id}{self};
}

sub _get_url_suffix {
  my $self = shift;
  my ($action) = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $suffix = $ENTITY_TABLE->{$entity_type}{_actions}{$action};
}

sub _self_url {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  return $ENTITY_TABLE->{$entity_type}{$$self}{self_url};
}

# get the $ENTITY_TABLE entry for the object
sub _entry {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  return $ENTITY_TABLE->{$entity_type}{$$self};
}

sub DESTROY {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  foreach (keys %{$ENTITY_TABLE->{$entity_type}{$$self}}) {
    delete $ENTITY_TABLE->{$entity_type}{$$self}{$_};
  }
  delete $ENTITY_TABLE->{$entity_type}{$$self};
  return;
}

=head1 NAME

REST::Neo4p::Entity - Base class for Neo4j entities

=head1 SYNOPSIS

Not intended to be used directly. Use subclasses
L<REST::Neo4p::Node|REST::Neo4p::Node>,
L<REST::Neo4p::Relationship|REST::Neo4p::Relationship> and
L<REST::Neo4p::Node|REST::Neo4p::Index> instead.

=head1 DESCRIPTION

C<REST::Neo4p::Entity> is the base class for the node, relationship
and index classes which should be used directly. The base class
encapsulates most of the L<REST::Neo4p::Agent|REST::Neo4p::Agent>
calls to the Neo4j server, converts JSON responses to Perl references,
acknowledges errors, and maintains the main object table.

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,
L<REST::Neo4p::Index>.

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

=cut

1;
