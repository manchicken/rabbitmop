package RabbitMop::UserContext;

use strict;
use warnings;

use Clone::PP qw{clone};

sub new {
	my ($pkg, %opts) = @_;

	return bless {_context=>{}}, $pkg;
}

sub set_context_for_action {
	my ($self, $action, $context) = @_;

	$self->{_context}->{$action} = clone $context;

	return;
}

sub get_context_for_action {
	my ($self, $action) = @_;

	return $self->{_context}->{$action || "__MISSING__"} || {};
}

sub all {
	my ($self) = @_;

	return $self->{_context};
}

1;