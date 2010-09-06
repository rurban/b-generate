#!/usr/bin/perl -w

use Test::More tests => 10;

use B qw(svref_2object);
BEGIN { use_ok 'B::Generate'; }

CHECK {
    my ($x, $y,$z);

    # Replace addition with subtraction
    for ($x = B::main_start; $x->type != B::opnumber("add"); $x=$x->next){ # Find "add"
        $y=$x;  # $y is the op before "add"
    };
    $z = B::BINOP->new("subtract",0,$x->first, $x->last); # Create replacement "subtract"

    $z->next($x->next); # Copy add's "next" across.
    $y->next($z);       # Tell $y to point to replacement op.
    $z->targ($x->targ);

    # Turn 30 into 13
    for(
        $x = B::main_start;
        B::opnumber("const") ne $x->type || $x->sv->sv ne 30;
        $x=$x->next
    ) {}
    $x->sv(13);

    # Turn "bad" into "good"
    for(
	$x = svref_2object($foo)->START;
	ref($x) ne 'B::NULL';
	$x = $x->next
    ) {
	next unless($x->can('sv'));
	if($x->sv->PV eq "bad") {
	    $x->sv("good");
	    last;
	}
    }

    # Turn "lead" into "gold"
    for(
	$x = svref_2object(\&foo::baz)->START;
	ref($x) ne 'B::NULL';
	$x = $x->next
    ) {
	next unless($x->can('sv'));
	if($x->sv->PV eq "lead") {
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

# This used to segv: assertion "PL_curcop == &PL_compiling" failed: file "op.c", line 2500
# with => 5.11 and >= 5.10.1 with DEBUGGING
ok( B::BINOP->new("add", 0, 0, 0) ); # fixed "panic: restartop"

BEGIN {
  $foo = sub {
    is( "bad", "good", "Turn bad into good" );
  }
}
$foo->();
foo::baz();

sub foo::baz {
    is( "lead", "gold", "Turn lead into gold" );
}

SKIP: {
    skip( q(->seq was removed for 5.10), 1 ) if $] >= 5.010;
    my $x = svref_2object(\&foo::baz);
    my $op = $x->START;
    my $y = $op->find_cv();
    is($x->ROOT->seq, $y->ROOT->seq);
}

{
    my $foo = "hi";
    my $x = svref_2object(\$foo);
    is($x->PV, "hi", 'svref2object');

    $x->PV("bar");
    is($x->PV, "bar", '  changing the value of a PV');
    is($foo, "bar",   ' and the associated lexical changes');
}
