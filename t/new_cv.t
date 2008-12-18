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
    ++$a;
}



sub prepend_function_with_inc {
    my $code = shift;

    my $whoami = B::svref_2object($code);
    isa_ok($whoami, 'B::CV');
    is($whoami->ROOT->name, 'leavesub');
    is($whoami->START->name, 'nextstate');
    my $leavesub = B::UNOP->new("leavesub", $whoami->ROOT->flags, $whoami->ROOT->first);
    is($leavesub->name, 'leavesub');

    my $inc_a = B::svref_2object(\&inc_a);
    my $inc_a_entry = $inc_a->START;
    is($inc_a_entry->name, 'nextstate');
    my $padsv = $inc_a->START->next;

    my $inc = $padsv->next;
    is($inc->name, 'preinc');

    my $nextstate = $whoami->START;
    is($nextstate->name, 'nextstate');

    $inc->sibling($nextstate);
    $inc->next($nextstate);

    my $orz_obj = $whoami->NEW_with_start($leavesub, $inc_a_entry);
#    my $orz_obj;
    return $orz_obj->object_2svref;
}

$orz = prepend_function_with_inc(\&dothat_and_1);

is(dothat_and_1(), 1);
is($a, 0);
is($orz->(), 1);
is($a, 1);

is($orz->(), 1);
is($a, 2);

$orz = prepend_function_with_inc(\&dothat_and_2);
is($orz->(), 1);

TODO: {
local $TODO = 'need to fix svop padlist idx';
is($a, 3);
is($b, 0);
}
