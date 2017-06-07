#!/usr/bin/env perl

=pod

=head1 NAME

dlq-tool.pl - A simple web tool to modify a DLQ

=head1 SYNOPSIS

dlq-tool.pl [options]

  Options:
    -h --help           display this help message
    -x --regex=REGEX    regular expression to apply when selecting messages (against body)
    -v --verbose        display verbose info as we go along
    -a --action=ACTION  the action to perform on the message
    -s --host=SERVER    the server
    -o --port=PORT      the port (default 5672)
    -u --user=USER      the user
    -p --password=WORD  the password
    -q --queue=QUEUE    the queue to get from
    -i --no-case        make the regular expression match case insensitive
    -l --limit=LIMIT    limit the action to only acting on LIMIT messages at most
    -f --file=FILE      write a dumper copy of the file to a file

=head1 OPTIONS

=over 4

=item B<--help>

Display help information

=item B<--regex>

This is a regular expression to apply to match the body against when considering the message

=item B<--verbose>

Display verbose information while we process

=item B<--action>

This is the action to perform. Current actions:

 * delete - Delete the message
 * print - Print the message

=item B<--connectUrl>

The URL to use when connecting.

=item B<--queue>

The queue to fetch from when processing.

=item B<--limit>

Stop processing after LIMIT messages have been processed.

=item B<--file>

Write the contents of the message in C<Data::Dumper> format to a FILE. If you
perform any action this will write the message.

=back

=head1 DEPENDENCIES

=over 4

=item Net::AMQP::RabbitMQ

Obviously, we need some sort of module to connect to RabbitMQ.

=item Readonly

You should have this installed already.

=item Mojolicious::Lite

This supports our web interface.

=back

=cut

use strict;
use warnings;
use 5.020;

use Readonly;

use Net::AMQP::RabbitMQ;
use Mojolicious::Lite;

Readonly my $VERSION => '0.1.0';
Readonly my $APP_NAME => 'DLQ Tool';
Readonly my $SUB_CHANNEL => 1;
Readonly my $PUB_CHANNEL => 2;

=pod

=head1 FUNCTIONS

=over 4

=item rmq_get_connection(%)

This function connects to RabbitMQ.

=back

=cut

sub rmq_get_connection {
  my %opts = @_;
  
  my $hostname = delete $opts{host};
  my $mq = Net::AMQP::RabbitMQ->new();
  $mq->connect( $hostname, \%opts );
  $mq->channel_open(1);
  
  return $mq;
}

=pod

=item rmq_finish($)

=cut

sub rmq_finish {
  my ($conn) = @_;

  $conn->channel_close( 1 );
  $conn->disconnect();

  return;
}


=pod

=head1 ENDPOINTS

Below are the various endpoints for the web interface.

=head2 GET /

This is the default landing page.

=cut

get '/' => {template=>'index'};

app->start;

__DATA__

@@ layouts/main.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= $title %></title></head>
  <body>
    % if (my $confirmation = flash 'confirmation') {
      <p><%= $confirmation %></p>
    % }
    <%= content %>
  </body>
</html>

@@ index.html.ep
% layout 'main', title => "DLQ Tool";

<% my $field = begin %>
  % my %opts = @_;
  % my $label = delete $opts{label};
  % my $name = delete $opts{name};
  % my $default = delete $opts{default};
  % $default ||= '';
  %= label_for $name => $label
  :&nbsp;
  %= text_field $name => $default, id => "field.${name}"
  <br/><br/>
<% end %>

<h1>Welcome to QueueMod.</h1>
%= form_for index => begin
%= $field->(label=>'RMQ Host', name=>'host')
%= $field->(label=>'RMQ Port', name=>'port', default=>'5672')
%= $field->(label=>'RMQ Vhost', name=>'vhost', default=>'/')
%= submit_button
% end

@@ find-form.html.ep


%= $field->(label=>'Read Queue', name=>'readQueue')
%= $field->(label=>'Re-publish Exchange', name=>'republishExchange')

<fieldset>
%= $field->(label=>' Regex', name=>'lookupRegex')
</fieldset>


__END__

use Getopt::Long;
use Pod::Usage;
use URI;
use Net::AMQP::RabbitMQ;

use Data::Dumper;

# We want to always be case-insensitive
Getopt::Long::Configure("ignorecase_always");

my $counter = 0;
my $actions = {
  # Print just displays and then rolls back
  print => sub {
    my ($mq, $opts) = @_;
    return rmq_rollback_action( sub {
      my $message = shift @_;
      print Dumper( $message );
      return 1;
    }, $mq, $opts );
  },
  
  # This will display the message and delete
  remove => sub {
    my ($mq, $opts) = @_;
    return rmq_commit_action( sub {
      my $message = shift @_;
      print Dumper( $message );
      $mq->ack( 1, $message->{delivery_tag} );
      return 1;
    }, $mq, $opts );
  },
};

sub parse_args {
  my $opts = {};
  
  Getopt::Long::GetOptions(
    $opts,
    'host|s=s',
    'user|u=s',
    'password|p=s',
    'port|o=i',
    'vhost=s',
    'regex|x=s',
    'verbose|v',
    'action|a=s',
    'queue|q=s',
    'limit|l=i',
    'file|f=s',
    'no-case|i'
  ) || pod2usage(-exitval=>1, -verbose=>1);
  
  # Enforce required parameters
  my @missing = ();
  for my $requiredParam ( qw/host user password action queue/ ) {
    if ( !exists $opts->{ $requiredParam } || !length $opts->{ $requiredParam } ) {
      push @missing, "$requiredParam";
    }
  }
  if ( scalar @missing ) {
    pod2usage(
      -msg => 'Missing required parameters: ' . join(', ', @missing),
      -exitval => 1,
      -verbose => 1,
    );
  }
  
  # Set the default port
  $opts->{port} ||= 5672;
  
  # Just for safety, prevent this from running as an admin user
  if ( $opts->{user} =~ m/admin/i ) {
    die "You really should not run this program as an admin user."
  }
  
  if ( ! exists $actions->{$opts->{action}} ) {
    pod2usage(
      -msg => "Unknown action >$opts->{action}<",
      -exitval => 1,
      -verbose => 1,
    );
  }
  
  return $opts;
}

sub write_file {
  my ( $msg, $opts ) = @_;
  
  my $filename = $opts->{file} ||
    return;
  
  my $outfile = IO::File->new( "$filename", "a" ) ||
    die "Cannot open file >$filename< for writing: $!";
  
  print $outfile Dumper($msg) . "\n";
  
  undef $outfile;
  
  return;
}

# Gives us a generic wrapper to make generating the actions easy
sub rmq_generic_action_wrapper {
  my ($action, $mq, $opts) = @_;
  
  my $make_re = sub {
    if ( ! $opts->{regex} ) {
      return;
    }
    
    my $re = $opts->{regex};

    if ( $opts->{'no-case'} ) {
      return qr!$re!ism;
    }
    
    return qr!$re!sm;
  };
  
  my $matches = sub {
    my ($subject) = @_;
    state $compiled_re = $make_re->();
    
    if ( $compiled_re ) {
      print Dumper({re=>$compiled_re, msg=>$subject}) if ( $opts->{verbose} );
      return ( $subject =~ $compiled_re );
    }
    
    return 1;
  };
  
  my $wrapper;
  $wrapper = sub {
    my ($cont) = @_;
    
    # If we're over our limit, we should stop here
    if ( exists $opts->{limit} && defined $opts->{limit} ) {
      return if ($opts->{limit} <= $counter);
    }
    
    # We're done if we don't have a continuation function
    return $counter if !$cont;

    $mq->tx_select( 1 );
    my $msg = $mq->get( 1, $opts->{queue}, {no_ack=>0} ) || do {
      $mq->tx_rollback( 1 );
      return;
    };
    
    return $wrapper->( $action->( $msg, $matches ) );
  };
  
  return $wrapper;
}

sub rmq_rollback_action {
  my ($action, $mq, $opts) = @_;
  
  return rmq_generic_action_wrapper( sub {
    my ($message, $matches) = @_;
    
    if ( $matches->($message->{body}) ) {
      write_file( $message, $opts );
      $counter += 1;
      $action->($message);
    }
    
    $mq->tx_rollback( 1 );
    return 1;
  }, $mq, $opts);
}

# Make an action which commits upon success
sub rmq_commit_action {
  my ($action, $mq, $opts) = @_;
  
  return rmq_generic_action_wrapper( sub {
    my ($message, $matches) = @_;
    
    if ( $matches->($message->{body}) ) {
      write_file( $message, $opts );
      $counter += 1;
      if ( $action->($message) ) {
        $mq->tx_commit( 1 );
        return 1;
      }
    }
    
    $mq->tx_rollback( 1 );
    return 1;
  }, $mq, $opts);
}

my $opts = parse_args();
my $mq = rmq_get_connection( $opts );

# Get the action and start the chain...
my $action = $actions->{$opts->{action}}->($mq, $opts);
$action->(1);
say "Processed >$counter< messages.";

# Clean things up.
rmq_finish( $mq );
