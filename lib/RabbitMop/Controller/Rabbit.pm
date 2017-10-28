package RabbitMop::Controller::Rabbit;
use Mojo::Base 'Mojolicious::Controller';

use RabbitMop::UserContext;
use Net::AMQP::RabbitMQ;
use JSON::PP;
use Readonly;

use Data::Dumper;

=pod

The amount of time that a websocket can sit idle without being closed.

=cut
Readonly my $INACTIVITY_TIMEOUT => 600;
Readonly my $CONNECTION_LIMIT => 5;
our $__alreadyConnected = 0;

=pod

This method provides WebSocket functionality for RabbitMQ.

We need this functionality here, and in a websocket transaction within Mojo,
because if we don't then we will lose context and be unable to maintain transactions.

=cut

sub socket {
  my ($self, $c) = @_;

  die "Already connected" if $__alreadyConnected > $CONNECTION_LIMIT;
  $__alreadyConnected += 1;

  $self->{mq} ||= undef;

  # Prep ourselves for the web socket...
  $self->app->log->debug('The socket has been opened');
  $self->inactivity_timeout($INACTIVITY_TIMEOUT);

  my $context = {};

  $self->on( message => $self->_message_handler($c, $context) );
  $self->on( finish  => $self->_finish_handler );
}

sub _message_handler {
	my ($self, $c, $context) = @_;

	return sub {
		my ($c, $msg) = @_;

		my $actions = {

			keepalive => sub {
				$c->app->log->debug("KEEPALIVE");
				return;
			},

			authenticate => sub {
				my ($args) = @_;

				$self->_txn_init($args)
			}
		};

		my $args = decode_json($msg);
		my $action = delete $args->{action};

		return $actions->{$action}->($args);
	}
}

sub _finish_handler {
	my ($self, $c, $context) = @_;

	$self->app->log->debug("Finish handler!");
}

# Next message...
sub _txn_init {
	my ($self, $args) = @_;

  $self->{mq} = Net::AMQP::RabbitMQ->new();

  eval {
	  $self->{mq}->connect( $args->{host}, {
	  	user     => $args->{username},
	  	password => $args->{password},
	  	port     => $args->{port} || 5672,
	  	vhost    => $args->{vhost} || '/',
		});
	};

	if ($@) {
		$self->app->log->error($@);
	}

	return;
}

sub _next_message {

}

sub _act_on_message {

}

sub _txn_finish {
	my ($self, $args) = @_;

	return if (!exists $self->{mq});

	eval { $self->{mq}->disconnect(); };
	$self->app->log->error($@) if ($@);

	$__alreadyConnected -= 1;
}

1;