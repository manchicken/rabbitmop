use Mojo::Base -strict;

use Test::More tests => 10;
use Test::Mojo;

my $t = Test::Mojo->new('RabbitMop');
$t->get_ok('/')
	->status_is(200)
	->content_like(qr/data-test=\"welcome-header\"/ix)
	->content_like(qr/LICENSE/)
	->element_exists('form input[name="csrf_token"]')
	->element_exists('form input[name="host"]')
	->element_exists('form input[name="port"]')
	->element_exists('form input[name="vhost"]')
	->element_exists('form input[name="username"]')
	->element_exists('form input[name="password"]')
;

done_testing();
