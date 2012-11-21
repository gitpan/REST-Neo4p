# -*- perl -*-
#$Id: 001_load.t 2 2012-10-30 14:31:22Z maj $


# t/001_load.t - check module loading and create testing directory

use Test::More tests => 1;

BEGIN { use_ok( 'REST::Neo4p' ); }



