package TestConstants;
use strict;
use warnings;

use Test::More;

use Readonly;
Readonly our $details => {
	username => q{nartest},
	password => q{reallysecure},
	host     => q{rabbitmq.thisaintnews.com},
	port     => 5672,
	vhost    => q{/},
};

sub location_like {
  my ($t, $re, $desc) = @_;
  $desc ||= "Location: $re";
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return $t->success(Test::More::like($t->tx->res->headers->location, $re, $desc));
};

1;