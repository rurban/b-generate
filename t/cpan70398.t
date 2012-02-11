# -*-perl -*- 
# B::Generate breaks Concise dumping of const ops on threaded perls
# https://rt.cpan.org/Public/Bug/Display.html?id=70398
# B::Generate B::SVOP->sv() read-only should not break B::SVOP->sv()
use Test::More tests => 3;

sub const_iv {
  my $s = shift;
  $s =~ m/const([\(\[]IV .+?[\)\]])/;
  return $1;
}

# broken on win95
my $X = $^X =~ m/\s/ ? qq{"$^X" -Iblib/arch -Iblib/lib} : "$^X -Iblib/arch -Iblib/lib";

my $pure=`$X -MO=-qq,Concise -lwe 'print 123'`;
# <$> const[IV 123] s ->5
like ($pure, qr/ const\[IV 123\]/m, "Concise without B::Generate");

my $polluted=`$X -MB::Generate -MO=-qq,Concise -lwe 'print 123'`;
TODO: {
  local $TODO = 'B::Generates pollutes B::Concise SVOP->sv output RT#70398';
  # <$> const(IV \32163568)[t1] s ->5
  is (const_iv($polluted), "[IV 123]", "Concise with B::Generate");
}

# workaround
my $workaround = q(-MO=-qq,Concise -lwe'BEGIN{require B;my $sv=\&B::SVOP::sv;require B::Generate;no warnings; *B::SVOP::sv=$sv;} print 123');
like (`$X $workaround`, qr/ const\[IV 123\]/m, "workaround");
