use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 12;

sub BEGIN {
	use_ok qw/RabbitMop::UserContext/;
}

my $uctx = RabbitMop::UserContext->new();
isa_ok($uctx, q{RabbitMop::UserContext});

# Positive tests...
{
	# Verify the key, prior to being set is good...
	is_deeply($uctx->get_context_for_action("002-user-context"), {});
	$uctx->set_context_for_action("002-user-context" => {a=>1,b=>2});
	is_deeply($uctx->get_context_for_action("002-user-context"), {a=>1,b=>2});
}

# Some negative tests...
{
	is_deeply($uctx->get_context_for_action(undef), {});
	is_deeply($uctx->get_context_for_action(""), {});
	is_deeply($uctx->get_context_for_action(""), {});
}

# Make sure that the context is keeping its own copy...
{
	my $foo = {foo=>123,bar=>456,blah=>{xx=>42}};
	$uctx->set_context_for_action(foo => $foo);
	is_deeply($uctx->get_context_for_action(q{foo}), {foo=>123,bar=>456,blah=>{xx=>42}});
	$foo->{baz} = 1;
	is_deeply($uctx->get_context_for_action(q{foo}), {foo=>123,bar=>456,blah=>{xx=>42}});
	$foo->{bar} = 876;
	is_deeply($uctx->get_context_for_action(q{foo}), {foo=>123,bar=>456,blah=>{xx=>42}});
	$foo->{blah} = 123;	
	is_deeply($uctx->get_context_for_action(q{foo}), {foo=>123,bar=>456,blah=>{xx=>42}});
}

# All...
{
	my $newctx = RabbitMop::UserContext->new();
	$newctx->set_context_for_action('foo', {foo=>1});
	$newctx->set_context_for_action('bar', {bar=>2});
	is_deeply($newctx->all, {foo=>{foo=>1}, bar=>{bar=>2}});
}

done_testing();
