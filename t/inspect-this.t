#!perl

use Test::More tests => 263;
use_ok 'B';

#use_ok 'B::Generate'; # cannot use here, due to clash with B::Concise

use BTest;

for (1..10) {
    $i += $_;
}

if ($i) {
    $i = "eye";
}

$i =~ /bar/;

my $str = "the quick brown fox";

$str =~ s/fox/bear/;

test_self_ops(); # -v => 2);

