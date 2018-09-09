package Mojo::AsyncAwait;

use Mojo::Base -strict;

use Carp();
use Coro ();
use Mojo::Util;
use Mojo::Promise;
use Scalar::Util ();

use Exporter 'import';

our @EXPORT = (qw/async await/);

sub async {
  my $sub = pop;
  my $name = shift;
  my $wrapped = sub {
    Coro->new(sub{
      eval { $sub->(@_); 1 } or return $Coro::main->throw($@);
      $Coro::main->schedule_to;
    }, @_)->schedule_to;
  };
  if ($name) {
    my $caller = caller;
    Mojo::Util::monkey_patch $caller, $name => $wrapped;
  };
  return $wrapped;
}

sub await {
  my $promise = shift;
  $promise = Mojo::Promise->new->resolve($promise)
    unless Scalar::Util::blessed($promise) && $promise->can('then');

  my $current = $Coro::current;
  my ($retval, $err);
  $promise->then(
    sub {
      $retval = shift;
      $current->schedule_to;
    },
    sub {
      $err = shift;
      $current->schedule_to;
    }
  );

  $Coro::main->schedule_to;
  Carp::croak($err) if $err;
  return $retval;
}

1;

