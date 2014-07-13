# -*- perl -*-
#$Id: 0010_load.t 451 2014-06-20 12:39:20Z maj $


# t/001_load.t - check module loading and create testing directory

use Test::More tests => 1;

BEGIN { use_ok( 'REST::Neo4p' ); }



