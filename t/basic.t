#!/usr/bin/perl -w

use Test::More tests => 10;

use B qw(svref_2object);
BEGIN { use_ok 'B::Generate'; }
use Config;
# $DEBUG = 1;

# With threaded perl optree changes are only allowed during BEGIN or CHECK
# CHECK
{
    my ($x, $y,$z);

    # Replace addition with subtraction

    # Note that threaded perl´s introduce B:NULL ops from the optimizer.
    # We would really need a non-threaded and a threaded recipe.
    my $add = B::opnumber("add");
    my $const = B::opnumber("const");
    for ($x = B::main_start; # Find "add", skip NULL
         $x->type != $add;
         $x=$x->next)
    {
        # $x->dump if $DEBUG;
        $y=$x;  # $y is the op before "add"
    };
    $z = B::BINOP->new("subtract",0,$x->first, $x->last); # Create replacement "subtract"

    $z->next($x->next); # Copy add's "next" across.
    $y->next($z);       # Tell $y to point to replacement op.
    $z->targ($x->targ);

    # Turn const(IV 30) into 13
    for($x = B::main_start;
        $x->type != $const or $x->sv->sv ne 30;
        $x=$x->next)
    {
        # $x->dump if $DEBUG;
    }
    ref($x) ne 'B::NULL' and $x->sv(13) and diag "changed add - const(IV 30) into 13";

    # Turn "bad" into "good" in &$foo
    for($x = svref_2object($foo)->START;
	ref($x) ne 'B::NULL';
	$x = $x->next)
    {
        $x->dump if $DEBUG;
        # there are 3 const args in &$foo after pushmark
        if ( $Config{useithreads} and $x->type == $const and ref($x->sv) ne 'B::SPECIAL' ) {
          diag "const(",$x->sv,")";
          diag "const(",$x->sv->sv,")";
          #diag "const(PV ",$x->sv->PV,")" if $x->sv->can('PV');
        }
        if ($x->type == $const and ref($x->sv) ne 'B::SPECIAL' and $x->sv->sv eq "bad") {
          $x->dump if $DEBUG;
          $x->sv("good");
          diag "changed 'bad' into 'good'";
          last;
        }
    }

    # Turn "lead" into "gold"
    for($x = svref_2object(\&foo::baz)->START;
	ref($x) ne 'B::NULL';
	$x = $x->next
    ) {
        # $x->dump if $DEBUG;
	next unless $x->can('sv') and $x->sv->can('PV');
	if ($x->sv->PV eq "lead") {
            diag "changed 'lead' into 'gold'";
	    $x->sv("gold");
	    last;
	}
    }

}

my $b; # STAY STILL!

$a = 17;
$b = 15;
is $a + $b, 2, "Changed addition to substraction";

$c = 30;
$d = 10;
is $c - $d, 3, "Changed the number 30 into 13";

# This used to segv: 
# assertion "PL_curcop == &PL_compiling" failed: file "op.c", line 2500
# with => 5.11 and >= 5.10.1 with DEBUGGING
ok( B::BINOP->new("add", 0, 0, 0), "new add" ); # fixed "panic: restartop"

BEGIN {
  $foo = sub {
    $Config{useithreads}
      ? pass( "SKIP Turn bad into good" )
      : is( "bad", "good", "Turn bad into good" );
  };
}
$foo->();
sub foo::baz {
    $Config{useithreads}
      ? pass( "SKIP Turn lead into gold" )
      : is( "lead", "gold", "Turn lead into gold" );
}
foo::baz();

{
  my $x = svref_2object(\&foo::baz);
  my $op = $x->START;
  my $y = $op->find_cv();
  $] < 5.010
    ? is($x->ROOT->seq, $y->ROOT->seq, "find_cv seq")
    : is(${$x->ROOT}, ${$y->ROOT}, "find_cv");
}

{
    my $foo = "hi";
    my $x = svref_2object(\$foo);
    is($x->PV, "hi", 'svref2object');

    $x->PV("bar");
    is($x->PV, "bar", '  changing the value of a PV');
    is($foo, "bar",   ' and the associated lexical changes');
}
