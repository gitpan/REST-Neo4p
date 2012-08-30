#$Id: Relationship.pm 17638 2012-08-30 03:52:17Z jensenma $
package REST::Neo4p::Relationship;
use base 'REST::Neo4p::Entity';
use REST::Neo4p::Exceptions;
use Carp qw(croak carp);
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Relationship::VERSION = '0.1';
}

sub new {
  my $self = shift;
  my ($from_node, $to_node, $type) = @_;
  unless (ref $from_node && $from_node->is_a('REST::Neo4p::Node') &&
	  ref $to_node && $to_node->is_a('REST::Neo4p::Node') &&
	  defined $type) {
    REST::Neo4p::LocalException->throw("Requires 2 REST::Neo4p::Node objects and a relationship type");
  }
  return $from_node->relate_to($to_node, $type);
}

sub type {
  my $self = shift;
  return $self->_entry->{type};
}

=head1 NAME

REST::Neo4p::Relationship - Neo4j relationship object

=head1 SYNOPSIS

 $n1 = $REST::Neo4p::Node->new( {name => 'Harry'} )
 $n2 = $REST::Neo4p::Node->new( {name => 'Sally'} );
 $r1 = $n1->relate_to($n2, 'met');
 $r1->set_property({ when => 'July' });

=head1 DESCRIPTION

C<REST::Neo4p::Relationship> objects represent Neo4j relationships.

=head1 METHODS

=over

=item new()

=item get_property()

=item set_property()

=item get_properties()

=item type()

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Index>.

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

=cut

1;
