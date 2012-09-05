#$Id: Agent.pm 17650 2012-08-31 03:41:43Z jensenma $
package REST::Neo4p::Agent;
use base LWP::UserAgent;
use REST::Neo4p::Exceptions;
use JSON;
use Carp qw(croak carp);
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Agent::VERSION = '0.1';
}

our $AUTOLOAD;
our $JSON = JSON->new()->allow_nonref(1);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->default_header( 'Accept' => 'application/json' );
  $self->default_header( 'Content-Type' => 'application/json' );
  $self->protocols_allowed( ['http','https'] );
  bless $self, $class;
}

sub server {
  my $self = shift;
  $self->{_server} = shift if @_;
  return $self->{_server};
}

sub connect {
  my $self = shift;
  my ($server) = @_;
  $self->{_server} = $server if defined $server;
  unless ($self->server) {
    REST::Neo4p::Exception->throw(message => 'Server not set');
   }
  my $resp = $self->get($self->server);
  unless ($resp->is_success) {
    REST::Neo4p::CommException->throw( code => $resp->code,
				       message => $resp->message );
    
  }
  my $json =  $JSON->decode($resp->content);
  # add the discovered URLs to the object hash, keyed by 
  # underscore + <function_name>:
  foreach (keys %{$json}) {
    next if /^extensions$/;
    # strip any trailing slash
    $json->{$_} =~ s|/+$||;
    $self->{_actions}{$_} = $json->{$_};
  }
  $resp = $self->get($self->{_actions}{data});
  unless ($resp->is_success) {
    REST::Neo4p::CommException->throw( code => $resp->code,
				       message => $resp->message." (connect phase 2)" );
  }
  $json = $JSON->decode($resp->content);
  foreach (keys %{$json}) {
    next if /^extensions$/;
    $self->{_actions}{$_} = $json->{$_};
  }
  # fix for incomplete discovery (relationship endpoint)
  unless ($json->{relationship}) {
    $self->{_actions}{relationship} = $self->{_actions}{node};
    $self->{_actions}{relationship} =~ s/node/relationship/;
  }

  return 1;
}

# contains a reference to the returned content, as decoded by JSON
sub decoded_content { shift->{_decoded_content} }
# contains the url representation of the node returned in the Location:
# header
sub location { shift->{_location} }

sub available_actions { keys %{shift->{_actions}} }

# autoload getters for discovered neo4j rest urls

sub AUTOLOAD {
  my $self = shift;
  my $method = $AUTOLOAD;
  $method =~ s/.*:://;
  my ($rq, $action) = $method =~ /^(get_|post_|put_|delete_)*(.*)$/;
  unless (grep /^$action$/,keys %{$self->{_actions}}) {
    REST::Neo4p::LocalException->throw( __PACKAGE__." does not define method '$method'" );
  }
  return $self->{_actions}{$action} unless $rq;
  $rq =~ s/_$//;
  # reset
  $self->{_errmsg} = $self->{_location} = $self->{_decoded_content} = undef;
  for ($rq) {
    /get|delete/ && do {
      my @url_components = @_;
      my %rest_params = ();
      # look for a hashref as final arg containing field => value pairs
      if (ref $url_components[-1] && (ref $url_components[-1] eq 'HASH')) {
	%rest_params = %{ pop @url_components };
      }
      my $resp = $self->$rq(join('/',$self->{_actions}{$action}, @url_components),%rest_params);
      eval { 
	$self->{_decoded_content} = $resp->content ? $JSON->utf8->decode($resp->content) : {};
      };
      unless ($resp->is_success) {
	if ( $self->{_decoded_content} ) {
	  REST::Neo4p::Neo4jException->throw( 
	    code => $resp->code,
	    neo4j_message => $self->{_decoded_content}->{message},
	    neo4j_exception => $self->{_decoded_content}->{exception},
	    neo4j_stacktrace =>  $self->{_decoded_content}->{stacktrace}
	      );
	}
	else {
	  REST::Neo4p::CommException->throw( 
	    code => $resp->code,
	    message => $resp->message
	    );
	}
      }
      $self->{_location} = $resp->header('Location');
      last;
    };
    /post|put/ && do {
      my ($url_components, $content) = @_;
      $content = $JSON->encode($content) if $content;
      my $resp  = $self->$rq(join('/',$self->{_actions}{$action},@$url_components), 'Content-Type' => 'application/json', Content=> $content);
      $self->{_decoded_content} = $resp->content ? $JSON->decode($resp->content) : {};
      unless ($resp->is_success) {
	if ( $self->{_decoded_content} ) {
	  my %error_fields = (
	    code => $resp->code,
	    neo4j_message => $self->{_decoded_content}->{message},
	    neo4j_exception => $self->{_decoded_content}->{exception},
	    neo4j_stacktrace =>  $self->{_decoded_content}->{stacktrace}
	   );
	  $error_fields{neo4j_exception} =~ /^Syntax/ ? 
	    REST::Neo4p::QuerySyntaxException->throw(%error_fields) :
		REST::Neo4p::Neo4jException->throw(%error_fields);
	}
	else {
	  REST::Neo4p::CommException->throw(
	    code => $resp->code,
	    message => $resp->message
	   );
	}
      }
      $self->{_location} = $resp->header('Location');
      last;
    };
    do { # fallthru
      croak "I shouldn't be here";
    };
  }
  return $self->{_decoded_content};
}

sub DESTROY {}

=head1 NAME

REST::Neo4p::Agent - LWP client interacting with Neo4j

=head1 SYNOPSIS

 $agent = REST::Neo4p::Agent->new();
 $agent->server('http://127.0.0.1:7474');
 unless ($agent->connect) {
  print STDERR "Didn't find the server\n";
 }

See examples under L</METHODS> below.

=head1 DESCRIPTION

The agent's job is to encapsulate and connect to the REST service URLs
of a running neo4j server. It also stores the discovered URLs for
various actions.  and provides those URLs as getters from the agent
object. The getter names are the keys in the JSON objects returned by
the server. See
L<http://docs.neo4j.org/chunked/milestone/rest-api.html> for more
details.

API and HTTP errors are distinguished and thrown by
L<Exception::Class|Exception::Class> subclasses. See
L<REST::Neo4p::Exceptions>.

C<REST::Neo4p::Agent> is a subclass of L<LWP::UserAgent|LWP::UserAgent>
and inherits its capabilities.

=head1 METHODS

=over

=item new()

 $agent = REST::Neo4p::Agent->new();
 $agent = REST::Neo4p::Agent->new("http://127.0.0.1:7474");

Returns a new agent. Accepts optional server address arg.

=item server()

 $agent->server("http://127.0.0.1:7474");

Sets the server address and port.

=item data()

 $neo4j_data_url = $agent->data();

Returns the base of the Neo4j server API.

=item admin()

 $neo4j_admin_url = $agent->admin();

Returns the Neo4j server admin url.

=item node()

=item reference_node()

=item node_index()

=item relationship_index()

=item extensions_info

=item relationship_types()

=item batch()

=item cypher()

 $relationship_type_url = $agent->relationship_types;

These methods get the REST URL for the named API actions. Other named
actions may also be available for a given server; these are
auto-loaded from self-discovery responses provided by Neo4j. Use
C<available_actions()> to identify them.

You will probably prefer using the L</get_{action}()>,
L</put_{action}()>, L</post_{action}()>, and L</delete_{action}()>
methods to make requests directly.

=item neo4j_version()

 $version = $agent->neo4j_version;

Returns the version of the connected Neo4j server.

=item available_actions()

 @actions = $agent->available_actions();

Returns all discovered actions.

=item errmsg()

Returns last error message. This is undef if the request was successful.

=item location()

 $agent->post_node(); # create new node
 $new_node_url = $agent->location;

Returns the value of the "location" key in the response JSON. 

=item get_{action}()

 $decoded_response = $agent->get_data(@url_components,\%rest_params)
 $types_array_ref = $agent->get_relationship_types();

Makes a GET request to the REST endpoint mapped to {action}. Arguments
are additional URL components (without slashes). If the final argument
is a hashref, it will be sent as key-value form parameters.

=item put_{action}()

 # add a property to an existing node
 $agent->put_node([13, 'properties'], { name => 'Herman' });

Makes a PUT request to the REST endpoint mapped to {action}. The first
argument, if present, must be an array B<reference> of additional URL
components. The second argument, if present, is a hashref that will be
sent in the request as (encoded) JSON content.

=item post_{action}()

 # create a new node with given properties
 $agent->post_node({ name => 'Wanda' });

Makes a POST request to the REST endpoint mapped to {action}. The first
argument, if present, must be an array B<reference> of additional URL
components. The second argument, if present, is a hashref that will be
sent in the request as (encoded) JSON content.

=item delete_{action}()

  $agent->delete_node(13);
  $agent->delete_node_index('myindex');

Makes a DELETE request to the REST endpoint mapped to {action}. Arguments
are additional URL components (without slashes). If the final argument
is a hashref, it will be sent in the request as (encoded) JSON content.

=item decoded_response()

 $decoded_json = $agent->decoded_response;

Returns the response content of the last agent request, as decoded by
L<JSON|JSON>. It is generally a reference, but can be a scalar if a
bareword was returned by the server.

=back

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
