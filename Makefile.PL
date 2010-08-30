use strict;
use 5.005062;
use ExtUtils::MakeMaker;
use Config;

my $lddlflags = $Config{lddlflags};
if ($^O eq 'darwin') {
  $lddlflags =~ s/-flat_namespace/-twolevel_namespace/;
  $lddlflags =~ s/-undefined suppress/-undefined error/;
  $lddlflags .= " $Config{archlibexp}/CORE/$Config{libperl}";
}

# Modules using B::Generate should do the same. See also below at test()
if ( $ENV{PERL_DL_NONLAZY} and $] > 5.009 ) {
  print "
Warning: CPAN #28912 Perl 5.10 effectively removed B::Generate support
by privatizing some essential libperl functions. They are not interested
in adding it again.
However it still works if do not set PERL_DL_NONLAZY, because those
functions are still in libperl - unices can access private functions -
until the next berserk will remove it from there also.
On Windows some other workarounds are used, but functionality is limited.
I've unset PERL_DL_NONLAZY for this test.
If you need PERL_DL_NONLAZY add -DDISABLE_PERL_CORE_EXPORTED to CCFLAGS.

";
}

WriteMakefile
  (
   'NAME'		=> 'B::Generate',
   'VERSION_FROM'	=> 'lib/B/Generate.pm',
   'PREREQ_PM'	=>
   {
    'B'                  => '1.09', # see rt29257 re OP_LIST
    'ExtUtils::CBuilder' => 0,
    'Module::Build'      => 0,
   },
   ABSTRACT_FROM => 'lib/B/Generate.pm',
   AUTHOR        => 'Simon Cozens',
   (($^O eq 'darwin') ?
     (LDDLFLAGS     => $lddlflags) : ()),
   # If you need PERL_DL_NONLAZY use this:
   # 'CCFLAGS'        => $Config{ccflags} . " -DDISABLE_PERL_CORE_EXPORTED",
   ($ExtUtils::MakeMaker::VERSION gt '6.46' ?
    ('META_MERGE'  =>
     {
      resources =>
      {
       MailingList => 'mailto:"600 subscribers" <perl5-porters@perl.org>',
       repository  => 'http://github.com/rurban/b-generate',
       license     => 'http://dev.perl.org/licenses/',
      },
     }
    ) : ()),
  );

package MY;
use Config;

sub ccflags {
  my $ccflags = shift->SUPER::ccflags(@_);
  $ccflags .= '-DPERL_CUSTOM_OPS -DPERL_CUSTOM_OPCODES -g' if $] >= 5.008;
  return $ccflags;
}

sub const_config {
  my $s = shift->SUPER::const_config(@_);
  #return $s unless $^O eq 'darwin';
  my ($lddlflags) = $s =~ /^LDDLFLAGS (.*)$/m;
  $lddlflags =~ s/-flat_namespace/-twolevel_namespace/;
  $lddlflags =~ s/-undefined suppress/-undefined error/;
  $lddlflags .= " $Config{archlibexp}/CORE/$Config{libperl}";
  $s =~ s/^LDDLFLAGS (.*)$/LDDLFLAGS $lddlflags/;
  return $s;
}

# Modules using B::Generate should do the same
sub test {
  local $_ = shift->SUPER::test(@_);
  s/PERL_DL_NONLAZY=1 //g;
  return $_;
}

sub depend {
  "
README : lib/B/Generate.pm
	pod2text lib/B/Generate.pm > README

gcov :
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -fprofile-arcs -ftest-coverage\" LDDLFLAGS=\"\$(LDDLFLAGS) -fprofile-arcs -ftest-coverage\"

gprof :
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -pg\" LDDLFLAGS=\"\$(LDDLFLAGS) -pg\"
"
}
