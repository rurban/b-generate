# -*-perl -*- 
# B::Generate <1.41 broke Concise dumping of const ops on threaded perls
# https://rt.cpan.org/Public/Bug/Display.html?id=70398
use Test::More tests => 3;

sub const_iv {
  my $s = shift;
  $s =~ m/const[\(\[](IV .+?)[\)\]]/;
  return $1;
}

# broken on win95, do not care enough
my $X = $^X =~ m/\s/ ? qq{"$^X" -Iblib/arch -Iblib/lib} : "$^X -Iblib/arch -Iblib/lib";

my $pure=`$X -MO=-qq,Concise -lwe 'print 123'`;
# <$> const[IV 123] s ->5
is (const_iv($pure), "IV 123", "Concise without B::Generate");

my $polluted=`$X -MB::Generate -MO=-qq,Concise -lwe 'print 123'`;
# was: <$> const(IV \32163568)[t1] s ->5
is (const_iv($polluted), "IV 123", "Concise with B::Generate");

# workaround
my $workaround = q(-MO=-qq,Concise -lwe'BEGIN{require B;my $sv=\&B::SVOP::sv;require B::Generate;no warnings; *B::SVOP::sv=$sv;} print 123');
like (`$X $workaround`, qr/const[\(\[]IV 123[\)\]]/, "workaround");
