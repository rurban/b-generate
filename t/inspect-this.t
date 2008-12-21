#!perl

BEGIN {
    $plan = $] < 5.0100
      ? ($] >= 5.008009 ? 650 : 658)
      : 648; # skip PV->LEN tests on 5.10
    use Config;
    require Test::More;
    if ($Config{PERL_PATCHLEVEL} and $] < 5.0100) {
	Test::More->import('no_plan');
    } else {
	Test::More->import(tests => $plan);
    }
}
use_ok 'B';

#use_ok 'B::Generate'; # cannot use here, due to clash with B::Concise

use BTest;

$i += $_ for 1..10;
for (1..10) {
    $i += $_;
}

my $j += $_ for 1..10;
for my $i (1..10) {
    $j += $i;
}

$j = "black" if $j;

if ($i) {
    $i = "eye";
}

$i =~ /bar/;
$j =~ s/black/grey/;

my $str = "the quick brown fox";

$str =~ s/fox/bear/;


sub Foo::bar { 1 }
my $f = bless {}, 'Foo';

$f->bar;


test_self_ops( -v => scalar @ARGV );

