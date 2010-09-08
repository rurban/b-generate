use strict;
use 5.005062;
use ExtUtils::MakeMaker;
use Config;
use ExtUtils::Embed qw(ccopts ldopts);

my $extracflags = '';
my $lddlflags = $Config{lddlflags};
if ($^O eq 'darwin') {
  $lddlflags =~ s/-flat_namespace/-twolevel_namespace/;
  $lddlflags =~ s/-undefined suppress/-undefined error/;
  $lddlflags .= " $Config{archlibexp}/CORE/$Config{libperl}";
}
my $ccflags = $Config{ccflags};
$ccflags .= " $extracflags";
$ccflags .= ' -DPERL_CUSTOM_OPS -DPERL_CUSTOM_OPCODES' if $] >= 5.008;

# Modules using B::Generate should do the same. See also below at test()
my $broken_plat = $^O =~ /MSWin32|AIX/;
$broken_plat = 1 if $^O eq 'cygwin' and $Config{gccversion} =~ /^4\./;
if ( $broken_plat and $] > 5.009 ) {
  # If you need PERL_DL_NONLAZY force this
  $ccflags .= " -DDISABLE_PERL_CORE_EXPORTED";
  print "
Warning: Perl 5.10 effectively removed B::Generate support
by privatizing some essential libperl functions, which is fatal
with strict linkers or a static libperl.
You can only use a subset of B::Generate functionality (CPAN #28912):
op->convert does not fold constants as the BINOP->new and UNOP->new counterparts,
cv->NEW_with_start disabled.

";
} elsif ( $ENV{PERL_DL_NONLAZY} and $] > 5.009 ) {
  print "
Warning: CPAN #28912 Perl 5.10 effectively removed B::Generate support
by privatizing some essential libperl functions, which is fatal
with strict linkers.
However it still works if you do not set PERL_DL_NONLAZY, because those
functions are still in libperl - unices can access unexported functions
in shared libs - until the next porter will remove it from there also.
I've unset PERL_DL_NONLAZY for this test.
If you need PERL_DL_NONLAZY add -DDISABLE_PERL_CORE_EXPORTED to CCFLAGS.

";
}

# Yet unused
# MSWin32 should have dumpbin, GNU systems nm, others I have no idea.
sub findexport {
  my $sym = shift;
  my $libperl = $Config{libperl};
  $libperl = "$Config{archlibexp}/CORE/$Config{libperl}" unless -f $libperl;
  return 0 unless -f $libperl;
  if ($^O eq 'MSWin32') {
    my $test = `dumpbin`;
    if ($test =~ /usage: DUMPBIN/) {
      `dumpbin /EXPORTS $libperl > perl.sym`;
      my $found = `find "$sym" perl.sym`;
      return $found =~ /$sym/;
    }
  } else {
    my $test = `nm --help`;
    if ($test =~ /Usage: nm/) {
      my $found = `nm -g "$libperl" | grep $sym`;
      return $found =~ /$sym/;
    }
  }
  return 0;
}

my $obj = $Config{obj_ext};
sub checkexport {
  #return 1;
  my $sym = shift;
  open C, ">", "test.c";
  print C << "EOF";
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "perlapi.h"
#include "XSUB.h"

int main (int argc, char **argv) {
pTHXx;
$sym;
}
EOF
  close C;

  my $cflags = ccopts;
  my $exe = $Config{exe_ext};
  my $redir = $^O eq 'MSWin32' ? "> NUL" : "2>&1 >/dev/null";
  print "\nTesting export for $sym\n";

  my $coredir = $ENV{PERL_SRC} || "$Config{installarchlib}/CORE";
  my $libdir  = "$Config{prefix}/lib";
  my $useshrplib = $Config{useshrplib};
  my $linkargs;
  if ($^O eq 'MSWin32' && $Config{cc} =~ m/^cl/i) {
    my $cmd = "$Config{cc} $cflags -c";
    print "$cmd\n";
    system($cmd);
    my $ok = ($? == 0) and -e "test.obj";
    return 0 unless $ok;

    $linkargs = ldopts("-std");
    $linkargs .= " perl5$Config{PERL_VERSION}.lib kernel32.lib msvcrt.lib";
    $cmd = "$Config{ld} test.obj $linkargs $redir";
    print "$cmd\n";
    system $cmd;
  }
  else {
    if ( -e "$coredir/$Config{libperl}" and $Config{libperl} !~ /\.(dll|so)$/ ) {
      # prefer static linkage manually, without broken ExtUtils::Embed 
      $linkargs = sprintf("%s $coredir/$Config{libperl} %s",
			  @Config{qw(ldflags libs)});
    } elsif ( $useshrplib and -e "$libdir/$Config{libperl}") {
      # debian: /usr/lib/libperl.so.5.10.1 and broken ExtUtils::Embed::ldopts
      $linkargs = ExtUtils::Embed::ldopts('-std');
      $linkargs =~ s|-lperl |$libdir/$Config{libperl} |;
    } else {
      $linkargs = ExtUtils::Embed::ldopts('-std');
    }
    my $cmd = "$Config{cc} $ccflags -I$coredir test.c $linkargs $redir";
    print "$cmd\n";
    system $cmd;
  }
  my $ok = $? == 0;
  print $ok ? " ok\n" : " not found\n";
  return $ok;
}

unless ($broken_plat) {
  END { unlink "a.out", "a.exe", "test.exe", "test$obj", "test.c"; };
  $ccflags .= " -DHAVE_PAD_ALLOC"
    if checkexport("Perl_pad_alloc(aTHX_ 0, SVs_PADTMP)");
  $ccflags .= " -DHAVE_CV_CLONE"
    if checkexport("CV* cv;\nPerl_cv_clone(aTHX_ cv)");
  $ccflags .= " -DHAVE_FOLD_CONSTANTS"
    if checkexport("OP* o;\n".($]<5.011?"Perl":"S")."_fold_constants(aTHX_ o)");
  print "\n";
} # else -DDISABLE_PERL_CORE_EXPORTED

WriteMakefile
  (
   'NAME'		=> 'B::Generate',
   'VERSION_FROM'	=> 'lib/B/Generate.pm',
   'PREREQ_PM'	=>
   {
    'B'                  => '1.09', # see rt29257 re OP_LIST
    'ExtUtils::CBuilder' => 0,
    'ExtUtils::Embed'    => 0,
   },
   ABSTRACT_FROM => 'lib/B/Generate.pm',
   AUTHOR        => 'Simon Cozens',
   (($^O eq 'darwin') ?
     (LDDLFLAGS     => $lddlflags) : ()),
   CCFLAGS        => $ccflags,
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

# sub const_config {
#   my $s = shift->SUPER::const_config(@_);
#   return $s unless $^O eq 'darwin';
#   my ($lddlflags) = $s =~ /^LDDLFLAGS (.*)$/m;
#   $lddlflags =~ s/-flat_namespace/-twolevel_namespace/;
#   $lddlflags =~ s/-undefined suppress/-undefined error/;
#   $lddlflags .= " $Config{archlibexp}/CORE/$Config{libperl}";
#   $s =~ s/^LDDLFLAGS (.*)$/LDDLFLAGS $lddlflags/;
#   return $s;
# }

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

gcov : Generate.c.gcov Generate.xs.gcov cover_db/Generate-xs.html

Generate.c.gcov Generate.xs.gcov : Generate.xs
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -fprofile-arcs -ftest-coverage\" LDDLFLAGS=\"\$(LDDLFLAGS) -fprofile-arcs -ftest-coverage\"
	gcov Generate.c Generate.xs

cover_db/Generate-xs.html : Generate.xs.gcov
	PERL5OPT=-MDevel::Cover make test
	-$^X -S gcov2perl Generate.c.gcov Generate.xs.gcov
	$^X -S cover

gprof :
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -pg\" LDDLFLAGS=\"\$(LDDLFLAGS) -pg\"
"
}
