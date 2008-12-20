#!perl -w
use strict;
use Test::More tests => 23;
use B::Generate;
use strict;
no warnings 'void';

my $orz;

sub foo {
    my $n = shift;
    return $orz->($n);
}

my ($a, $b) = 0;

sub dothat_and_1 {
    $a;
    1;
}

sub dothat_and_2 {
    $b, $a;
    1;
}

sub inc_a {
    # print "# $a:",B::svref_2object(\$a),"\n" if $^P;
    ++$a;
}

sub prepend_function_with_inc {
    my $code = shift;

    my $whoami = B::svref_2object($code);
    isa_ok($whoami, 'B::CV');
    is($whoami->ROOT->name, 'leavesub', 'leavesub');
    is($whoami->START->name, ($^P ? 'dbstate' : 'nextstate'), 'nextstate');
    my $leavesub = B::UNOP->new("leavesub", $whoami->ROOT->flags, $whoami->ROOT->first);
    is($leavesub->name, 'leavesub', 'leavesub');
    my $nextstate = $whoami->START;
    is($nextstate->name, ($^P ? 'dbstate' : 'nextstate'), 'nextstate');

    my $inc_a = B::svref_2object(\&inc_a);
    if ($] >= 5.010 and $^P) {
        # TODO: The padidx is empty in pp_preinc since 5.10.
        # TARG flag and value missing for the inc_a call, op_private=33 (HASTARG)
        # padsv: flags=50 (0x32), private=0, targ=1, opt=1
        #$inc_a->targ(1);
        #$inc_a->private(33);
        print "# code=",$whoami,"\n";
        print "# inc_a=", $inc_a, ", inc_a->OUTSIDE->PADLIST=",$inc_a->OUTSIDE->PADLIST,"\n";
        print "# OUTSIDE=", $inc_a->OUTSIDE, ", PADLIST=",$inc_a->PADLIST,
          ", FLAGS=",$inc_a->FLAGS, ", OUTSIDE_SEQ=", $inc_a->OUTSIDE_SEQ, "\n";
        print "# padout=",$inc_a->OUTSIDE->PADLIST->ARRAY,"\n";
        print "# mypad=",$inc_a->PADLIST->ARRAY,"\n";
        print "# a=",B::svref_2object(\$a),"\n";
        #print "# pad[0]:",$inc_a->PADLIST->ARRAY,"\n";
        #print "# pad[1]:",$inc_a->PADLIST->ARRAY,"\n";
    }
    my $inc_a_entry = $inc_a->START;
    is($inc_a_entry->name, ($^P ? 'dbstate' : 'nextstate'), 'nextstate');
    my $padsv = $inc_a->START->next;

    my $inc = $padsv->next;
    while ($inc->name ne 'preinc') {
        $inc = $inc->next;
        last if $inc->name eq 'entersub';
    }
    is($inc->name, 'preinc', 'preinc');
    $inc->sibling($nextstate);
    $inc->next($nextstate);

    # entersub: $whoami->private(33) if ($] >= 5.010);
    my $orz_obj = $whoami->NEW_with_start($leavesub, $inc_a_entry);
    # => SV = PVCV(flags=0x40)[ B::GV ]
    return $orz_obj->object_2svref;
}

$orz = prepend_function_with_inc(\&dothat_and_1);

is(dothat_and_1(), 1, 'dothat_and_1 returns 1');
is($a, 0, 'a is 0');

SKIP: {
    skip( q(need to fix svop padlist idx for 5.10), 12 ) if $] >= 5.010 and $^P == 0;
    is($orz->(), 1, 'orz returns 1');
    is($a, 1, 'a is 1');

    is($orz->(), 1, 'orz returns 1');
    is($a, 2, 'a is 2');

    $orz = prepend_function_with_inc(\&dothat_and_2);
    is($orz->(), 1, 'dothat_and_2: orz returns 1');
}

TODO: {
  local $TODO = 'need to fix svop padlist idx';
  is($a, 3, 'a is 3');
  is($b, 0, 'b is 0');
}

# dumps core at END with 5.8.6 and lower
# END { undef $orz; }
