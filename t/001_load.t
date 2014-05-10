# -*- perl -*-
#$Id: 001_load.t 415 2014-05-05 03:00:37Z maj $


# t/001_load.t - check module loading and create testing directory

use Test::More tests => 1;

BEGIN { use_ok( 'REST::Neo4p' ); }



