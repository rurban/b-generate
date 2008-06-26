#!perl
use Test::More tests => 2;
use_ok 'B';

# B::Generate.pm comments say "MUST FIX CONSTANTS", 2x, with *emphasis*.
# Whats more, OP_LIST value has changed over releases.
# So we better test for it.

# 1st test is baseline, not even using/testing B::Generate.  This
# insures that we get failure reports until we get right
# release-dependent values, which we reverify using B-Gen in 2nd test

my %list_nums = (
    145 => "5.011000",
    142 => "5.010000",
    141 => "5.008008",	# probably should be 5.008(00[12])?
    );

my $got = B::opnumber("list");
my $vers = $list_nums{$got};

if ($vers) {
    # our opnum matches a known one, test that our version agrees
    ok($] >= $list_nums{$got}, "B::opnumber('list') -> $got on $]");
}
else {
    ok(0, "no ref data - please send this: B::opnumber('list') -> $got on $]");
}
