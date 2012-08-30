#$Id: Query.pm 17640 2012-08-30 13:46:38Z jensenma $
package REST::Neo4p::Query;
use REST::Neo4p::Path;
use REST::Neo4p::Exceptions;
use Carp qw(croak carp);
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Query::VERSION = '0.1';
}

sub new {
  my $class = shift;
  my ($q_string, $params) = @_;
  unless (defined $q_string and !ref $q_string) {
    REST::Neo4p::LocalException->throw( "First argument must be the query string");
  }
  unless (!defined $params || ref($params) eq 'HASH') {
    REST::Neo4p::LocalException->throw( "Second argment must be a hashref of query paramters" );
  }
  bless { '_query' => $q_string,
	  '_params' => $params || {},
	  'Statement' => $q_string,
	  'NUM_OF_PARAMS' => $params ? scalar keys %$params : 0,
	  'ParamValues' => $params
	}, $class;
}

sub execute {
  my $self = shift;
  my $agent = $REST::Neo4p::AGENT;
  REST::Neo4j::CommException->throw('Not connected') unless $agent;
  $self->{_error} = undef;
  $self->{_decoded_resp} = undef;
  $self->{NAME} = undef;
  $self->{_returned_rows} = undef;
  my $resp;
  eval {
    $resp = $self->{_decoded_resp} = $agent->post_cypher([], { query => $self->query, params => $self->params } );
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::Neo4jException') ) {
    $self->{_error} = $e;
    $e->rethrow if ($self->{RaiseError});
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  $self->{NAME} = $resp && $resp->{columns};
  $self->{NUM_OF_FIELDS} = $resp ? scalar @{$resp->{columns}} : 0;
  $self->{_returned_rows} = $resp && $resp->{data};
  return scalar @{$self->{_returned_rows}};
}


sub do {
  my $class = shift;
  REST::Neo4p::ClassOnlyException->throw() if (ref $class);

}

sub fetchrow_array {
  my $self = shift;
  return unless $self->{_returned_rows} && @{$self->{_returned_rows}};
  my $row = shift @{$self->{_returned_rows}};
  my @ret;
  foreach my $elt (@$row) {
    for (ref($elt)) {
      !$_ && do {
	push @ret, $elt;
	last;
      };
      /HASH/ && do {
	my $entity_type;
	eval {
	  $entity_type = _response_entity($elt);
	};
	my $e;
	if ($e = Exception::Class->caught()) {
	  ref $e ? $e->rethrow : die $e;
	}
	my $entity_class = 'REST::Neo4p::'.$entity_type;
	push @ret, $entity_class->new_from_json_response($elt);
	last;
      };
      /ARRAY/ && do {
	REST::Neo4p::LocalException->("Don't know what to do with arrays yet");
	last;
      };
      do {
	REST::Neo4p::QueryResponseException->throw("Can't parse query response");
      };
    }
  }
  return \@ret;
}
sub fetch { shift->fetchrow_array(@_) }

sub column_names {
  my $self = shift;
  return $self->{_column_names} && @{$self->{_column_names}};
}

sub err { 
  my $self = shift;
  return $self->{_error} && $self->{_error}->code;
}

sub errstr { 
  my $self = shift;
  return $self->{_error} && ( $self->{_error}->message || $self->{_error}->neo4j_message );
}


sub query { shift->{_query} }
sub params { shift->{_params} }

sub _response_entity {
  my ($resp) = @_;
  if (defined $resp->{self}) {
    for ($resp->{self}) {
      m|data/node| && do {
	return 'Node';
	last;
      };
      m|data/relationship| && do {
	return 'Relationship';
	last;
      };
      do {
	REST::Neo4p::QueryResponseException->throw("Can't identify object type by JSON response");
      };
    }
  }
  elsif (defined $resp->{start} && defined $resp->{end}
	   && defined $resp->{nodes}) {
    return 'Path';
  }
  else {
    REST::Neo4p::QueryResponseException->throw("Can't identify object type by JSON response (2)");
  }
}


=head1 NAME

REST::Neo4p::Query - Execute Neo4j Cypher queries

=head1 SYNOPSIS

 REST::Neo4p->connect('http:/127.0.0.1:7474');
 $query = REST::Neo4p::Query->new('START n=node(0) RETURN n');
 $query->execute;
 $node = $query->fetch->[0];
 $node->relate_to($other_node, 'link');

=head1 DESCRIPTION

C<REST::Neo4p::Query> encapsulates Neo4j Cypher language queries,
executing them via C<REST::Neo4p::Agent> and returning an iterator
over the rows, in the spirit of L<DBI|DBI>.

=head1 METHODS

=over

=item new()

 $stmt = 'START n=node({node_id}) RETURN n';
 $query = REST::Neo4p::Query->new($stmt,{node_id => 1});

Create a new query object. First argument is the Cypher query
(required). Second argument is a hashref of parameters (optional).

=item execute()

 $numrows = $query->execute;

Execute the query on the server.

=item fetch(), fetchrow_array()

 $query = REST::Neo4p::Query->new('START n=node(0) RETURN n, n.name');
 $query->execute;
 while ($row = $query->fetch) { 
   print 'It works!" if ($row->[0]->get_property('name') == $row->[1]);
 }

Fetch the next row of returned data (as an arrayref). Nodes are
returned as L<REST::Neo4p::Node|REST::Neo4p::Node> objects,
relationships are returned as
L<REST::Neo4p::Relationship|REST::Neo4p::Relationship> objects,
scalars are returned as-is.

=item err(), errstr()

  $query->execute;
  if ($query->err) {
    printf "status code: %d\n", $query->err;
    printf "error message: %s\n", $query->errstr;
  }

Returns the HTTP error code and Neo4j server error message if an error
was encountered on execution. Set C<$query-E<gt>{RaiseError}> to die
immediately (e.g., to catch the exception in an C<eval> block).

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Agent>.

=head1 AUTHOR

   Mark A. Jensen
   CPAN ID: MAJENSEN
   majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2012 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
1;
