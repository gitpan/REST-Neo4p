#-*-perl-*-
#$Id: 005_db.t 39 2012-11-21 04:26:01Z maj $
use Test::More tests => 32;
use Test::Exception;
use Module::Build;
use lib '../lib';
use strict;
use warnings;
no warnings qw(once);

my @cleanup;
my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 31;

use_ok('REST::Neo4p');

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : ".$e->message;
}
SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  ok my $n1 = REST::Neo4p::Node->new(), 'node 1';
#  push @cleanup, $n1 if $n1;
  ok my $n2 = REST::Neo4p::Node->new(), 'node 2';
  push @cleanup, $n2 if $n2;
  ok my $r12 = $n1->relate_to($n2, "bubba"), 'relationship 1->2';

  ok my $n3 = REST::Neo4p->get_node_by_id($$n1), 'got node by id';
  is $$n3, $$n1, 'same node';
  ok my $r = REST::Neo4p->get_relationship_by_id($$r12), 'got relationship by id';
  is $$r, $$r12, 'same relationship';
  ok my @rtypes = REST::Neo4p->get_relationship_types, 'get relationship type list';
  ok grep(/bubba/,@rtypes), 'found relationship type in type list';

  ok my $node_idx = REST::Neo4p::Index->new('node', 'node_idx'), 'new node index';
 # push @cleanup, $node_idx if $node_idx;
  ok my $reln_idx = REST::Neo4p::Index->new('relationship', 'reln_idx'), 'new relationship index';
  push @cleanup, $reln_idx if $reln_idx;
  ok my @idxs = REST::Neo4p->get_indexes('node'), 'get node indexes';
  is $idxs[0]->type, 'node', 'got a node index';
  ok @idxs = REST::Neo4p->get_indexes('relationship'), 'get relationship indexes';

  ok $node_idx->add_entry($n1, 'node' => 1), 'add node entry';
  ok $node_idx->add_entry($n2, 'node' => 2), 'add node entry';
  ok $reln_idx->add_entry($r12, 'reln' => 'bubba'), 'add reln entry';

  # test finding nodes, relns, idxs from scratch (no entry in ENTITY_TABLE)
  delete $REST::Neo4p::Entity::ENTITY_TABLE->{node}{$$n1};
  delete $REST::Neo4p::Entity::ENTITY_TABLE->{relationship}{$$r12};
  delete $REST::Neo4p::Entity::ENTITY_TABLE->{index}{$$node_idx};
  ok !defined $n1->_entry, 'node 1 gone from ENTITY_TABLE';
  ok !defined $r12->_entry, 'relationship 12 gone from ENTITY_TABLE';
  ok !defined $node_idx->_entry, 'node index gone from ENTITY_TABLE';

  ok my $N = REST::Neo4p->get_node_by_id($$n1), 'restore node 1 from db';
  push @cleanup, $N if $N;
  ok my $R = REST::Neo4p->get_relationship_by_id($$r12), 'restore relationship 12 from db';
  ok my $I = REST::Neo4p->get_index_by_name($$node_idx, 'node'), 'restore node index from db';
  push @cleanup, $I if $I;

  is $$N, $$n1, 'got node 1 back';
  is $$R, $$r12, 'got relationship 12 back';
  is $$I, $$node_idx, 'got node index back';
  is ${($I->find_entries('node' => 1))[-1]}, $$n1, 'resurrected index works';
  
  ok $R->remove, 'remove relationship';
  ok !REST::Neo4p->get_relationship_by_id($$r12), 'relationship is gone';
  lives_ok { $REST::Neo4p::AGENT->delete_node($$N) } 'delete node';
#  ok $REST::Neo4p::AGENT->delete_relationship($$R);
  lives_ok { $REST::Neo4p::AGENT->delete_node_index($$I) } 'delete node index';
}

END {

  CLEANUP : {
      1;
  }
}
