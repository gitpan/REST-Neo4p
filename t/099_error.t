#-*-perl-*-
#$Id: 004_db.t 17586 2012-08-26 04:48:17Z jensenma $
use Test::More qw(no_plan);
use Test::Exception;
use Module::Build;
use lib '../lib';
use REST::Neo4p;
use strict;
use warnings;
no warnings qw(once);

my $build;
eval {
  $build = Module::Build->current;
};

my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 10;

throws_ok { REST::Neo4p->get_indexes } 'REST::Neo4p::CommException', 'not connected ok';
like $@->message, qr/not connected/i, 'not connected ok (2)';

throws_ok { REST::Neo4p::Entity->new() } 'REST::Neo4p::NotSuppException', 'attempt to instantiate Entity ok';

throws_ok { REST::Neo4p->connect('http://127.0.0.1:9999') } 'REST::Neo4p::CommException', 'bad address ok';

throws_ok { REST::Neo4p::Query->new('fake query')->do() } 'REST::Neo4p::ClassOnlyException', 'Query do class only ok';

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : ".$e->message;
}

SKIP : {
    skip 'no connection to neo4j',$num_live_tests if $not_connected;
    my $n1 = REST::Neo4p::Node->new();
    throws_ok { $n1->set_property('boog') } 'REST::Neo4p::LocalException', 'bad set_property arg ok';

    ok $n1->remove, 'remove node';
}
