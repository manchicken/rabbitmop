package RabbitMop;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');
	$self->plugin('DefaultHelpers');
	$self->plugin('TagHelpers');

  return $self->establish_routes();
}

sub establish_routes {
	my ($self) = @_;

  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('start#welcome');
  $r->post('/auth')->to('auth#attempt');

  return;
}

1;
