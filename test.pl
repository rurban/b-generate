BEGIN { $| = 1; print "1..10\n"; }
END {print "not ok 1\n" unless $loaded;}
use B qw(svref_2object);
use B::Generate;
$loaded = 1;
print "ok 1\n";
BEGIN {
#    @B::NULL::ISA = 'B::OP';
}
######################### End of black magic.

CHECK{


    my ($x, $y,$z);
    $x = B::main_start; 
    for ($x = B::main_start; $x->type != B::opnumber("add"); $x=$x->next){ # Find "add"
        $y=$x;  # $y is the op before "add"
    };
    $z = new B::BINOP("subtract",0,$x->first, $x->last); # Create replacement "subtract"

    
    $z->next($x->next); # Copy add's "next" across.
    $y->next($z);       # Tell $y to point to replacement op.
    $z->targ($x->targ);
    my $i = 0;
    for(
        $x = B::main_start;
        B::opnumber("const") != $x->type || $x->sv->sv != 30;
        $x=$x->next){}
    $x->sv(13);

    for(
	$x = svref_2object($foo)->START;
	ref($x) ne 'B::NULL';
	$x = $x->next) {
	next unless($x->can(sv));
	if($x->sv->PV eq "not ok 5\n") {
	    $x->sv("ok 5\n");
	    last;
	}
    }

    for(
	$x = svref_2object(\&foo::baz)->START;
	ref($x) ne 'B::NULL';
	$x = $x->next) {
	next unless($x->can(sv));
	if($x->sv->PV eq "not ok 6\n") {
	    $x->sv("ok 6\n");
	    last;
	}
    }

} 

my $b; # STAY STILL!

$a = 17; $b = 15; print "ok ", $a + $b, "\n";
$c = 30; $d = 10; print "ok ", $c - $d, "\n";

my $newop = B::BINOP->new("add", 0, undef, undef); # This used to segv
print "ok 4\n";
BEGIN {
$foo = sub {
    
    print "not ok 5\n";
}
}
$foo->();
foo::baz();

sub foo::baz {
    print "not ok 6\n";
}

{
    my $x = svref_2object(\&foo::baz);
    my $op = $x->START;
    my $y = $op->find_cv();
    if($x->ROOT->seq == $y->ROOT->seq) {
	print "ok 7\n";
    } else {
	print "not ok 7\n";
    }
}

{
    my $foo = "hi";
    my $x = svref_2object(\$foo);
    if($x->PV eq "hi") { 
	print "ok 8\n";
    } else {
	print "not ok 8\n";
    }
    $x->PV("bar");
    if($x->PV eq "bar") { 
	print "ok 9\n";
    } else {
	print "not ok 9\n";
    }
    if($foo eq "bar") { 
	print "ok 10\n";
    } else {
	print "not ok 10\n";
    } 

}
