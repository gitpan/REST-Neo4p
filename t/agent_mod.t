#-*-perl-*-
#$Id$
use Test::More;
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

my $agent1 = REST::Neo4p->agent;
my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
}

SKIP : {
    skip 'no connection to neo4j',$num_live_tests if $not_connected;
    pass 'Connected';
    REST::Neo4p->agent->timeout(0.1);
    my $agent2 = REST::Neo4p->agent;
    eval {
      REST::Neo4p->connect('http://www.zzyxx.foo:7474');
    };
    if ( my $e = REST::Neo4p::CommException->caught() ) {
      like $e->message, qr/timeout/, 'timed out ok';
    }
    is $agent1, $agent2, 'same agent';

  }
done_testing;

