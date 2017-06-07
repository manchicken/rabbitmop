package TestConstants;
use strict;
use warnings;

use Readonly;
Readonly our $details => {
	username => q{nartest},
	password => q{reallysecure},
	host     => q{rabbitmq.thisaintnews.com},
	port     => 5672,
	vhost    => q{/},
};

1;