# -*-perl -*- 
# B::Generate <1.42 broke Deparse warnings objects
# https://rt.cpan.org/Public/Bug/Display.html?id=70396
use Test::More tests => 2;
SKIP: { 
  skip "TODO catch stderr with some module",2 if $^O eq 'MSWin32';

# broken on win95, do not care enough
my $X = $^X =~ m/\s/ ? qq{"$^X" -Iblib/arch -Iblib/lib} : "$^X -Iblib/arch -Iblib/lib";

my $pass = `$X  -MO=Deparse -e '123' 2>&1`;
unlike ($pass, qr/While deparsing/, "Deparse sanity");

my $fail = eval{`$X -MB::Generate -MO=Deparse -e '123' 2>&1`;};
unlike ($fail, qr/While deparsing/, "bad B::COP->warnings from B::Generate");

}
