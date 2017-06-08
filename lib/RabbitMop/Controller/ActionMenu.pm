package RabbitMop::Controller::ActionMenu;
use Mojo::Base 'Mojolicious::Controller';

use RabbitMop::UserContext;

# This action will render a template
sub welcome {
  my $self = shift;  

  # Render template "example/welcome.html.ep" with message
  $self->render();

  return;
}

1;