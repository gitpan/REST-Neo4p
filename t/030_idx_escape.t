#-*- perl -*-
#$Id$

use Test::More qw(no_plan);
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
  my @node_defs = 
    (
     { name => 'A', type => 'purine' },
     { name => 'T', type => 'pyrimidine' },
     { name => 'G', type => 'purine'},
     { name => 'C', type => 'pyrimidine' }
    );
  @cleanup = my ($A,$T,$G,$C) = map { REST::Neo4p::Node->new($_) } @node_defs;

  ok my $nt_names = REST::Neo4p::Index->new('node','nt_names'), 'create node index(2)';

  push @cleanup, $nt_names if $nt_names;

  ok $nt_names->add_entry($T, 'nickname' => 'old thymy',
			  'friends_call_him' => 'Mr T'), 
			    'add multiple key/values';
  ok my ($mrt) = $nt_names->find_entries('friends_call_him' => 'Mr T'), 'found multiply added entry';
  is $mrt->get_property('name'), 'T', 'found right node' if $mrt;

  CLEANUP : {
    ok ($_->remove, 'entity removed') for reverse @cleanup;
  }
  }
