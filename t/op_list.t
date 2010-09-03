#!perl
use Test::More tests => 2;
use_ok 'B';

# B::Generate.pm comments used to say "MUST FIX CONSTANTS",
# 2x, with *emphasis*.
# What's more, OP_LIST value has changed over releases.
# This is not required anymore. We keep this test just for reference.

# 1st test is baseline, not even using/testing B::Generate.  This
# insures that we get failure reports until we get right
# release-dependent values, which we reverify using B-Gen in 2nd test

my %list_nums = (
    146 => "5.012000",
    146 => "5.011001",  # added boolkeys to 141 with 2e0eeeaafce11cb0128
    145 => "5.011000",
    142 => "5.010000",
    142 => "5.008009",
    141 => "5.008008",	# probably should be 5.008(00[12])?
    141 => "5.008007",
    141 => "5.008006",
    141 => "5.008005",
    141 => "5.008004",
    141 => "5.008003",
    141 => "5.008002",
    141 => "5.008001",
    141 => "5.008000",
    141 => "5.006002",
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
