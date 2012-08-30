#-*-perl-*-
#$Id: 005_db.t 17619 2012-08-29 13:41:02Z jensenma $
use Test::More tests => 15;
use Module::Build;
use lib '../lib';
use strict;
use warnings;
no warnings qw(once);

my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 14;

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
  ok my $n2 = REST::Neo4p::Node->new(), 'node 2';
  ok my $r12 = $n1->relate_to($n2, "bubba"), 'relationship 1->2';
  ok my $n3 = REST::Neo4p->get_node_by_id($$n1), 'got node by id';
  is $$n3, $$n1, 'same node';
  ok my $r = REST::Neo4p->get_relationship_by_id($$r12), 'got relationship by id';
  is $$r, $$r12, 'same relationship';
  ok my @rtypes = REST::Neo4p->get_relationship_types, 'get relationship type list';
  ok grep(/bubba/,@rtypes), 'found relationship type in type list';
  ok $r->remove, 'remove relationship';
  ok !REST::Neo4p->get_relationship_by_id($$r12), 'relationship is gone';

  TODO : {
      local $TODO = "db index functions";
      ok my @idxs = REST::Neo4p->get_indexes('node'), 'get node indexes';
      is $idxs[0]->type, 'node', 'got a node index';
      ok @idxs = REST::Neo4p->get_indexes('relationship'), 'get relationship indexes';
  }
}
