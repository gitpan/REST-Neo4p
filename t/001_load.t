# -*- perl -*-
#$Id: 001_load.t 17 2012-11-14 01:01:52Z maj $


# t/001_load.t - check module loading and create testing directory

use Test::More tests => 1;

BEGIN { use_ok( 'REST::Neo4p' ); }



