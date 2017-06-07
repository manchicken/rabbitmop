package RabbitMop::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller';

use RabbitMop::UserContext;

# Attempt AMQP authentication. If this works, redirect to the menu.
# Otherwise go back to the start#welcome
sub attempt {
  my $self = shift;

  my $val = $self->validation;

  $val->csrf_protect;
  $val->required('username', 'trim');
  $val->required('password');
  $val->required('host', 'trim');
  $val->optional('vhost', 'trim');
  $val->optional('port');

  # Failed CSRF? 401.
  if ($val->has_error('csrf_token')) {
  	return $self->respond_to(
  		any => { data => '', status => 401 }
  	);
  }

  # We've got errors, return to the form.
  if ( $val->has_error ) {
  	return $self->render(controller=>'start', action=>'welcome');
  }

  # Store context and go to the menu
  my $uctx = RabbitMop::UserContext->new();
  $uctx->set_context_for_action('auth#attempt', {
  	params=>$self->req->params->to_hash
  });
  $self->session('uctx', $uctx);
	return $self->redirect_to(controller=>'action-menu', action=>'welcome');
}

1;
