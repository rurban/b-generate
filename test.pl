BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use B::Generate;
$loaded = 1;
print "ok 1\n";

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

    for(
        $x = B::main_start;
        B::opnumber("const") != $x->type || $x->sv->sv != 30;
        $x=$x->next){}
    $x->sv(13);

} 

$a = 17; $b = 15; print "ok ", $a + $b, "\n";
$c = 30; $d = 10; print "ok ", $c - $d, "\n";
