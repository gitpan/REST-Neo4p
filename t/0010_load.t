# -*- perl -*-
#$Id: 0010_load.t 479 2014-07-13 02:30:33Z maj $


# t/001_load.t - check module loading and create testing directory

use Test::More tests => 1;

BEGIN { use_ok( 'REST::Neo4p' ); }



