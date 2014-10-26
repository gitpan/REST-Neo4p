#-*-perl-*-
#$Id$
use Test::More tests => 5;
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
my $num_live_tests = 4;

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
  throws_ok {
    REST::Neo4p::Entity::new_from_json_response('REST::Neo4p::Index');
  } 'REST::Neo4p::LocalException', 'new_from_json_response(undef) throws local exception';
  throws_ok { 
    my $idx = REST::Neo4p->get_index_by_name('node','sxxcfdsjgjkllrarsdwejrkl')
  } 'REST::Neo4p::NotFoundException', 'missing index throws not found execption';
  ok ref $@;
  like $@->message, qr/sxxcfdsjgjkllrarsdwejrkl/, 'message returned';

  CLEANUP : {
      1;
  }
}
