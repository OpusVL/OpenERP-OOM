#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'OpenERP::OOM' ) || print "Bail out!
";
}

diag( "Testing OpenERP::OOM $OpenERP::OOM::VERSION, Perl $], $^X" );
