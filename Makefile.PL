use strict;
use warnings;

use ExtUtils::MakeMaker;
use ExtUtils::testlib;

WriteMakefile(
	NAME => 'RabbitMop',
	LICENSE => 'perl_5',
  MIN_PERL_VERSION => "5.020",
  VERSION   => '0.01',
  PREREQ_PM => {
  	'Mojolicious' => '7.25',
  	'Net::AMQP::RabbitMQ' => '2.30000',
  	'Math::Int64' => '0.54',
  },
  "TEST_REQUIRES" => {
    "Test::Mojo" => 0,
    "Test::More" => 0,
	},
  test      => {TESTS => 't/*.t'}
);
