use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 17;
use Test::Mojo;

use TestConstants;

my $t = Test::Mojo->new('RabbitMop');
$t->ua->max_redirects(1);

$t->get_ok('/')
	->status_is(200)
	->content_like(qr{data-test=\"welcome-header\"}ix)
	->content_like(qr{LICENSE})
	->element_exists('form input[name="csrf_token"]')
	->element_exists('form input[name="host"]')
	->element_exists('form input[name="port"]')
	->element_exists('form input[name="vhost"]')
	->element_exists('form input[name="username"]')
	->element_exists('form input[name="password"]')
;

my $csrf_token = $t->tx->res->dom->at('form input[name="csrf_token"]')->val;

# Post the with authentication and verify we can't log in with the wrong password.
$t->post_ok('/auth'
	=> {Accept => '*/*'}
	=> form => {
		csrf_token => $csrf_token,
		host       => $TestConstants::details->{'host'},
		port       => $TestConstants::details->{'port'},
		username   => $TestConstants::details->{'username'},
		password   => $TestConstants::details->{'password'}.'xxxx',
	})
	->status_is(200)
	->content_like(qr{data-test=\"welcome-header\"}ix)
	->content_like(qr{ACCESS_REFUSED}x)
;

# Post the with authentication and verify we can log in.
$t->post_ok('/auth'
	=> {Accept => '*/*'}
	=> form => {
		csrf_token => $csrf_token,
		host       => $TestConstants::details->{'host'},
		port       => $TestConstants::details->{'port'},
		username   => $TestConstants::details->{'username'},
		password   => $TestConstants::details->{'password'},
	})
	->status_is(200)
	->content_like(qr{data-test=\"find-messages-header\"}x)
;

done_testing();
