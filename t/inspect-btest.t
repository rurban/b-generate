#!perl

use Test::More tests => 30;
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

my $root = B::main_root();
testop($root,
       bcons => 'e9 <@> leave[1 ref] vKP/REFC ->(end)',
       name => 'leave',
    );
my $rn = $root->next;
isa_ok( $rn, "B::NULL", "root->next is B::NULL");

testop($exe[3],
       name => 'const',
       bcons => '4  <$> const[PV "B"] sM ',
       class => 'B::SVOP',
       flags => &B::OPf_WANT_SCALAR | &B::OPf_MOD,
       sv => sub {
	   my $sv = shift;
	   my $res =
	       '->PV "' .$sv->PV ."\"\n" .
	       '->PVX "' .$sv->PVX ."\"\n" .
	       '->CUR "' .$sv->CUR ."\"\n" .
	       '->LEN "' .$sv->LEN ."\"\n" ;
       },
);

testop($exe[8],
       bcons => '9  <$> const[PV "B::Generate"] sM ',
       name => 'const',
       class => 'B::SVOP',
       flags => &B::OPf_WANT_SCALAR | &B::OPf_MOD,
       sv => sub {
	   my $sv = shift;
	   my $res;
	   ok($res = $sv->PV, "->PV $res");
	   ok($res = $sv->PVX, "->PVX $res");
	   ok($res = $sv->CUR, "->CUR $res");
	   ok($res = $sv->LEN, "->LEN $res");
	   1;
       },
    );

