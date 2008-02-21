#!perl

use feature ':5.10';
use Test::More tests => 584;
use_ok 'B';
use_ok 'B::Generate';

#use lib '.';
use BTest;

# Store ops in exe order, so linkage tests are easier.  Ops which have
# been optimized away cannot be tested, but theyre B::NULL anyway,
# which doesnt support any methods.  There are siblings which havent
# been pruned, which should be testable. (premonition?)

my $next = B::main_start();
eval {
    do { push @exe, $next }
    while ($next = $next->next);
    # eventually dies on B::NULL
};

sub dostuff {
    # test from subroutine
    testop($exe[3],
	   name => 'const',
	   bcons => '4  <$> const[PV "B"] sM ',
	   class => 'B::SVOP',
	   sv => sub {
	       my $sv = shift;
	       my $res =
		   '->PV "' .$sv->PV ."\"\n" .
		   '->PVX "' .$sv->PVX ."\"\n" .
		   '->CUR "' .$sv->CUR ."\"\n" .
		   '->LEN "' .$sv->LEN ."\"\n" ;
	   },
	   flags => &B::OPf_WANT_SCALAR | &B::OPf_MOD);
    
    testop($exe[8],
	   bcons => '9  <$> const[PV "B::Generate"] sM ',
	   name => 'const',
	   class => 'B::SVOP',
	   sv => sub {
	       my $sv = shift;
	       my $res;
	       ok($res = $sv->PV, "->PV $res");
	       ok($res = $sv->PVX, "->PVX $res");
	       ok($res = $sv->CUR, "->CUR $res");
	       ok($res = $sv->LEN, "->LEN $res");
	       1;
	   },
	   flags => &B::OPf_WANT_SCALAR | &B::OPf_MOD);
}
dostuff();
    
my $root = B::main_root();
testop($root,
       bcons => 'e9 <@> leave[1 ref] vKP/REFC ->(end)',
       name => 'leave',
    );
my $rn = $root->next;
isa_ok( $rn, "B::NULL", "root->next is B::NULL");

test_all_ops(\@exe, <<'EO_RENDER')
1  <0> enter 
2  <;> nextstate(main 821 inspect-btest.t:5) v:%,{
3  <0> pushmark s
4  <$> const[PV "B"] sM
5  <#> gv[*use_ok] s
6  <1> entersub[t2] vKS/TARG,1
7  <;> nextstate(main 821 inspect-btest.t:6) v:%,{
8  <0> pushmark s
9  <$> const[PV "B::Generate"] sM
a  <#> gv[*use_ok] s
b  <1> entersub[t4] vKS/TARG,1
c  <;> nextstate(main 1226 inspect-btest.t:16) v:%,{
d  <0> pushmark s
e  <#> gv[*B::main_start] s
f  <1> entersub[t7] sKS/TARG,1
g  <0> padsv[$next:1226,1238] sRM*/LVINTRO
h  <2> sassign vKS/2
i  <;> nextstate(main 1229 inspect-btest.t:17) v:%,{
j  <|> entertry(other->k) v
1u <;> nextstate(main 1228 inspect-btest.t:18) v:%
1v <0> enter v
1w <0> pushmark s
1x <#> gv[*exe] s
1y <1> rv2av[t9] lKRM/1
1z <0> padsv[$next:1226,1238] l
20 <@> push[t10] vK/2
21 <0> unstack v
22 <0> pushmark s
23 <0> padsv[$next:1226,1238] sM
24 <$> method_named[PV "next"] s
25 <1> entersub[t11] sKS/TARG
26 <0> padsv[$next:1226,1238] sRM*
27 <2> sassign sKPS/2
28 <|> and(other->1w) vK/1
29 <@> leave vK*
k  <@> leavetry vK
l  <;> nextstate(main 1236 inspect-btest.t:54) v:%,{
m  <0> pushmark s
n  <#> gv[*dostuff] s
o  <1> entersub[t13] vKS/TARG,1
p  <;> nextstate(main 1236 inspect-btest.t:56) v:%,{
q  <0> pushmark s
r  <#> gv[*B::main_root] s
s  <1> entersub[t16] sKS/TARG,1
t  <0> padsv[$root:1236,1238] sRM*/LVINTRO
u  <2> sassign vKS/2
v  <;> nextstate(main 1237 inspect-btest.t:57) v:%,{
w  <0> pushmark s
x  <0> padsv[$root:1236,1238] lM
y  <$> const[PV "bcons"] sM/BARE
z  <$> const[PV "hand mangled to avoid confusing BTest"] sM
10 <$> const[PV "name"] sM/BARE
11 <$> const[PV "leave"] sM
12 <#> gv[*testop] s
13 <1> entersub[t18] vKS/TARG,1
14 <;> nextstate(main 1237 inspect-btest.t:61) v:%,{
15 <0> pushmark s
16 <0> padsv[$root:1236,1238] sM
17 <$> method_named[PV "next"] s
18 <1> entersub[t20] sKS/TARG
19 <0> padsv[$rn:1237,1238] sRM*/LVINTRO
1a <2> sassign vKS/2
1b <;> nextstate(main 1238 inspect-btest.t:62) v:%,{
1c <0> pushmark s
1d <0> padsv[$rn:1237,1238] sM
1e <$> const[PV "B::NULL"] sM
1f <$> const[PV "root->next is B::NULL"] sM
1g <#> gv[*isa_ok] s
1h <1> entersub[t22] vKS/TARG,1
1i <;> nextstate(main 1238 inspect-btest.t:64) v:%,{
1j <0> padsv[$rn:1237,1238] s
1k <|> and(other->1l) vK/1
EO_RENDER
if $rn;

__END__

# these ops fail test cuz theyre not in @exe, due to branching

1l     <0> pushmark s
1m     <0> pushmark sRM
1n     <#> gv[*exe] s
1o     <1> rv2av[t25] lKRM/1
1p     <1> refgen lKM/1
1q     <$> const[PV ""] sM
1r     <#> gv[*test_all_ops] s
1s     <1> entersub[t26] vKS/TARG,1
1t <@> leave[1 ref] vKP/REFC

z  <$> const[PV "e9 <@> leave[1 ref] vKP/REFC ->(end)"] sM
