#! /usr/bin/perl -w -I ..
#
# MySQL Database Server Tests via check_mysql_healthdb
#
#
# These are the database permissions required for this test:
#  GRANT SELECT ON $db.* TO $user@$host INDENTIFIED BY '$password';
#  GRANT SUPER, REPLICATION CLIENT ON *.* TO $user@$host;
# Check with:
#  mysql -u$user -p$password -h$host $db

use strict;
use Test::More;
use NPTest;

use vars qw($tests);

plan skip_all => "check_mysql_health not compiled" unless (-x "./check_mysql_health");

plan tests => 51;

my $bad_login_output = '/Access denied for user /';
my $mysqlserver = getTestParameter( 
		"NP_MYSQL_SERVER", 
		"A MySQL Server with no slaves setup"
		);
my $mysql_login_details = getTestParameter( 
		"MYSQL_LOGIN_DETAILS", 
		"Command line parameters to specify login access",
		"-u user -ppw -d db",
		);
my $with_slave = getTestParameter( 
		"NP_MYSQL_WITH_SLAVE", 
		"MySQL server with slaves setup"
		);
my $with_slave_login = getTestParameter( 
		"NP_MYSQL_WITH_SLAVE_LOGIN", 
		"Login details for server with slave", 
		"-uroot -ppw"
		);

my $result;
SKIP: {
	$result = NPTest->testCmd("./check_mysql_health -V");
	cmp_ok( $result->return_code, '==', 0, "expected result");
	like( $result->output, "/check_mysql_health \\(\\d+\\.\\d+\\)/", "Expected message");

	$result = NPTest->testCmd("./check_mysql_health --help");
	cmp_ok( $result->return_code, '==', 0, "expected result");
	like( $result->output, "/slave-lag/", "Expected message");
	like( $result->output, "/slave-io-running/", "Expected message");
	like( $result->output, "/slave-sql-running/", "Expected message");
	like( $result->output, "/threads-connected/", "Expected message");
	like( $result->output, "/threadcache-hitrate/", "Expected message");
	like( $result->output, "/querycache-hitrate/", "Expected message");
	like( $result->output, "/keycache-hitrate/", "Expected message");
	like( $result->output, "/bufferpool-hitrate/", "Expected message");
	like( $result->output, "/tablecache-hitrate/", "Expected message");
	like( $result->output, "/table-lock-contention/", "Expected message");
	like( $result->output, "/temp-disk-tables/", "Expected message");
	like( $result->output, "/connection-time/", "Expected message");
	like( $result->output, "/slow-queries/", "Expected message");
	like( $result->output, "/qcache-lowmem-prunes/", "Expected message");
	like( $result->output, "/bufferpool-wait-free/", "Expected message");
	like( $result->output, "/log-waits/", "Expected message");

}

SKIP: {
	$result = NPTest->testCmd("./check_mysql_health -H $mysqlserver -m connection-time -u dummy -pdummy");
	cmp_ok( $result->return_code, '==', 2, "Login failure");
	like( $result->output, "/CRITICAL - Cannot connect to database: Error: Access denied/", "Expected login failure message");

	$result = NPTest->testCmd("./check_mysql_health");
	cmp_ok( $result->return_code, "==", 3, "No mode defined" );
	like( $result->output, "/Must specify a mode/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m connection-time -w 10 -c 30");
	cmp_ok( $result->return_code, "==", 0, "Connected" );
	like( $result->output, "/OK - Connection Time ([0-9\.]+) usecs|connection_time=([0-9\.]+);10;30/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m keycache-hitrate -w :10 -c 2");
	cmp_ok( $result->return_code, "==", 2, "Connected" );
	like( $result->output, "/CRITICAL - Key Cache Hitrate at ([0-9\.]+)%|keycache_hitrate=([0-9\.]+)%;:10;2/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m qcache-hitrate -w :10 -c 2");
	cmp_ok( $result->return_code, "==", 2, "Connected" );
	like( $result->output, "/CRITICAL - Query Cache Hitrate at ([0-9\.]+)%|qcache_hitrate=([0-9\.]+)%;:10;2/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m qcache-hitrate -w :10 -c 2 -v 2>&1");
	cmp_ok( $result->return_code, "==", 2, "Connected" );
	like( $result->output, "/NOTICE: we have results/", "Verbose output");
	like( $result->output, "/CRITICAL - Query Cache Hitrate at ([0-9\.]+)%|qcache_hitrate=([0-9\.]+)%;:10;2/", "Correct error message");

}

SKIP: {
	my $slow_queries_last = 0;
	my $slow_queries = 0;
        my $delta = 0;
	$result = NPTest->testCmd("./check_mysql_health -m slow-queries -w :10 -c 2");
	sleep 1;
	$result = NPTest->testCmd("./check_mysql_health -m slow-queries -w :10 -c 2 -v 2>&1");
	ok( $result->output =~ /Load variable Slow_queries \(([0-9]+)\) /);
	$slow_queries_last = $1;
	ok( $result->output =~ /Result column 1 returns value ([0-9]+) /);
	$slow_queries = $1;
	$delta = $slow_queries - $slow_queries_last;
	ok( $result->output =~ /OK - ([0-9]+) slow queries/);
	cmp_ok($1, "==", $delta);
}

SKIP: {
	# performance data
	$result = NPTest->testCmd("./check_mysql_health -m slow-queries -w :11 -c :22 -v 2>&1");
	like( $result->output, "/slow_queries_rate=[0-9\.]+;:11;:22 slow_queries=[0-9]+;:11;:22/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m qcache-lowmem-prunes -w :11 -c :22 -v 2>&1");
	like( $result->output, "/lowmem_prunes_rate=[0-9\.]+;:11;:22 lowmem_prunes=[0-9]+;:11;:22/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m bufferpool-wait-free -w :11 -c :22 -v 2>&1");
	like( $result->output, "/bufferpool_free_waits_rate=[0-9\.]+;:11;:22 bufferpool_free_waits=[0-9]+;:11;:22/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m log-waits -w :11 -c :22 -v 2>&1");
	like( $result->output, "/log_waits_rate=[0-9\.]+;:11;:22 log_waits=[0-9]+;:11;:22/", "Correct error message");
}

SKIP: {
        skip "Has a slave server", 6 if $with_slave;

	$result = NPTest->testCmd("./check_mysql_health -m slave-lag");
	cmp_ok( $result->return_code, "==", 2, "No slave" );
	like( $result->output, "/CRITICAL - Slave lag NULL|slave_lag=0;10;20/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m slave-io-running");
	cmp_ok( $result->return_code, "==", 2, "No slave" );
	like( $result->output, "/CRITICAL - Slave io not running|slave_io_running=0/", "Correct error message");

	$result = NPTest->testCmd("./check_mysql_health -m slave-sql-running");
	cmp_ok( $result->return_code, "==", 2, "No slave" );
	like( $result->output, "/CRITICAL - Slave sql not running|slave_io_running=0/", "Correct error message");

}

SKIP: {
	skip "No mysql server with slaves defined", 5 unless $with_slave;
	$result = NPTest->testCmd("./check_mysql_health -H $with_slave $with_slave_login");
	cmp_ok( $result->return_code, '==', 0, "Login okay");

	$result = NPTest->testCmd("./check_mysql_health -S -H $with_slave $with_slave_login");
	cmp_ok( $result->return_code, "==", 0, "Slaves okay" );

	$result = NPTest->testCmd("./check_mysql_health -S -H $with_slave $with_slave_login -w 60");
	cmp_ok( $result->return_code, '==', 0, 'Slaves are not > 60 seconds behind');

	$result = NPTest->testCmd("./check_mysql_health -S -H $with_slave $with_slave_login -w 60:");
	cmp_ok( $result->return_code, '==', 1, 'Alert warning if < 60 seconds behind');
	like( $result->output, "/^SLOW_SLAVE WARNING:/", "Output okay");
}
