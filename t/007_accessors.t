#-*-perl-*-
#$Id: 007_accessors.t 17650 2012-08-31 03:41:43Z jensenma $
use Test::More qw(no_plan);
use Test::Exception;
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
my $num_live_tests = 1;

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
  $REST::Neo4p::CREATE_AUTO_ACCESSORS = 1;
  ok my $n1 = REST::Neo4p::Node->new(), 'node 1';
  ok my $n2 = REST::Neo4p::Node->new(), 'node 2';
  ok my $r12 = $n1->relate_to($n2, "bubba"), 'relationship 1->2';

  ok $n1->set_property({ dressing => 'mayo' }), 'node prop set with set_property';
  lives_and { is $n1->dressing, 'mayo' } 'getter works';
  lives_and { ok $n1->set_dressing('italian') } 'setter called';
  lives_and { is $n1->dressing, 'italian' } 'setter works';
  ok $r12->set_property({ method => 'drizzled', amount => 'lots' }), 'reln prop set with set_property';
  lives_and { is $r12->method, 'drizzled' } 'getter works (1)';
  lives_and { is $r12->amount, 'lots' } 'getter works (2)';
  lives_and { ok $r12->set_amount('little bit') } 'setter called';
  lives_and { is $r12->amount, 'little bit' } 'setter works';

  CLEANUP : {
      ok $r12->remove, 'remove relationship';
      ok $n1->remove, 'remove node';
      ok $n2->remove, 'remove ndoe';
  }
}