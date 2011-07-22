#!/usr/bin/perl -w
# TEST: m&&pb t/basic.t 2> b.log; pb -MO=Concise,-main,foo::baz t/basic.t >> b.log
# alias p=perl
# alias pb='p -Mblib'
# alias m=make
use Test::More tests => 9;

use B qw(svref_2object);
use B::Generate;
# use B::Flags;
use Config;

sub debug_const { # XXX unused. bizarre copy of ARRAY in entersub
  my $x = shift;
  my $pad = shift;
  my $sv = !${$x->sv} ? $pad->[$x->targ] : $x->sv;
  diag "const ",ref($x);
  diag "const->sv ",ref($x->sv);
  diag "pad[",ref $sv," ",ref($sv) !~ /^B::(NULL|SPECIAL)$/ ? $sv->sv :'undef',"]t",$x->targ;
}

# With a threaded perl optree changes are only allowed during BEGIN or CHECK
CHECK
{
    my ($x,$y,$z);
    # $DB::single=1 if defined &DB::DB;
    my $DEBUG = 0;

    # Replace add op with subtract op in main_cv

    # Note that threaded perl´s introduce B:NULL ops from the optimizer.
    # We would really need a non-threaded and a threaded recipe.
    my $add = B::opnumber("add");
    my $const = B::opnumber("const");
    for ($x = B::main_start; # Find "add", skip NULL
	 $x->type != $add;
         $x=$x->next)
    {
        #$x->dump if $DEBUG;
        $y=$x;  # $y is the op before "add"
    };
    diag "found first add";
    $y->next->dump if $DEBUG;
    $z = B::BINOP->new("subtract",0,$x->first, $x->last); # Create replacement "subtract"

    $z->next($x->next); # Copy add's "next" across.
    $y->next($z);       # Tell $y to point to replacement op.
    $z->targ($x->targ);

    # Turn const(IV 30) into 13. The const is always after the add.
    $x = $y->next->next;
    diag "search for const(IV 30) after the add";
    if ($Config::Config{useithreads}) {
      $DEBUG = 0;
      my $cv = B::main_cv;
      my @pad = (($cv->PADLIST->ARRAY)[1]->ARRAY);
      # threaded: const SVOP: if ->op_sv=B:NULL => PAD, else ->sv
      while ($$x) {
        if ($x->type == $const) {
	  my $sv = $pad[$x->targ];
	  #my $sv = !${$x->sv} ? $pad[$x->targ] : $x->sv;
          #my $sv = (ref($x->sv) eq 'B::NULL') ? $pad[$x->targ] : $x->sv;
	  if ($DEBUG) {
	    diag "const ",ref($x);
	    diag "const->sv ",ref($x->sv);
            my $val = ref($sv) eq 'B::SPECIAL' ? ["Null", "sv_undef", "sv_yes", "sv_no"]->[${$sv}]
              : (ref($sv) eq 'B::NULL' ? 'undef' : $sv->sv);
            diag "pad[",ref $sv," ",$val,"]/t",$x->targ;
	  }
	  if ( ref($sv) ne 'B::NULL' and $sv->sv eq 30 ) {
	    diag "found const(IV 30)";
	    $x->sv(13) and diag "changed add - const(IV 30) into 13";
	    last;
	  }
        }
	# $x->dump if ref($x) ne 'B::NULL' and $DEBUG;
	$x = $x->next;
      }
    } else {
      for(; # unthreaded: const (SVOP) to global IV
          $x->type != $const or $x->sv->sv ne 30;
          $x=$x->next)
        {
        }
      if (ref($x) ne 'B::NULL') {
        diag "found const(IV 30)";
        $x->dump if $DEBUG;
        $x->sv(13) and diag "changed add - const(IV 30) into 13";
      }
    }
}

my $b; # STAY STILL!

$a = 17;
$b = 15;
is $a + $b, 2, "Changed addition op to substraction op in main_cv";

$c = 30;
$d = 10;
is $c - $d, 3, "Changed the const(IV 30) into 13 in main_cv";

# This used to segv: 
# assertion "PL_curcop == &PL_compiling" failed: file "op.c", line 2500
# with => 5.11 and >= 5.10.1 with DEBUGGING
ok( B::BINOP->new("add", 0, 0, 0), "new add op in main_cv" ); # fixed "panic: restartop"

BEGIN {
  $foo = sub {
    my $s = "Turn bad into good in an ANON subref";
    #$Config::Config{useithreads}
    #  ? pass( "TODO ".$s ) :
      is( "bad", "good", $s );
  };
}

CHECK
{
    my ($x,$y,$z);
    # $DB::single=1 if defined &DB::DB;
    my $DEBUG = 0;
    my $const = B::opnumber("const");

    diag "search for const(PV 'bad') in ANON &$foo";
    if ($Config::Config{useithreads}) {
      $DEBUG = 0;
      my $cv = svref_2object($foo);
      my @pad = (($cv->PADLIST->ARRAY)[1]->ARRAY);
      $x = $cv->START;
      while ($$x) {
        if ($x->type == $const) { # SVOP
	  my $sv = $pad[$x->targ];
	  #my $sv = !${$x->sv} ? $pad[$x->targ] : $x->sv;
	  #my $ix = ref($x) eq "B::SVOP" ? $x->targ : $x->padix;
	  #my $sv = (ref($x) eq "B::PADOP" or !${$x->sv}) ? $pad[$ix] : $x->sv;
	  #my $sv = $x->sv;
	  if ($DEBUG) {
	    diag "const ",ref($x);
	    diag "const->sv ",ref($x->sv);
            diag "pad[",ref $sv," ",ref($sv) !~ /^B::(NULL|SPECIAL)$/ ? $sv->sv :'undef',"]t",$x->targ;
	  }
	  if ( ref($sv) ne 'B::NULL' and $sv->sv eq 'bad' ) {
	    $x->sv("good", $foo);
	    diag "changed 'bad' into 'good'";
	    last;
	  }
        }
	#$x->dump if $DEBUG;
	last if ref $x eq 'B::NULL';
	$x = $x->next;
      }
    } else {
      for($x = svref_2object($foo)->START;
	  ref($x) ne 'B::NULL';
	  $x = $x->next
	 ) {
        # $x->dump if $DEBUG;
	next unless $x->can('sv');
	if ($x->sv->PV and $x->sv->PV eq "bad") {
	  diag "changed 'bad' into 'good'";
	  $x->sv("good");
	  last;
	}
      }
    }
}

$foo->();
sub foo::baz {
    my $s = "Turn lead into gold in a sub";
    #$Config::Config{useithreads}
    #  ? pass( "TODO ".$s ) :
      is( "lead", "gold", $s );
}

CHECK
{
    my ($x,$y,$z);
    # $DB::single=1 if defined &DB::DB;
    my $DEBUG = 1;
    my $const = B::opnumber("const");

    diag "search for const(PV 'lead') in &foo::baz";
    if ($Config::Config{useithreads}) {
      $DEBUG = 1;
      my $cv = svref_2object(\&foo::baz);
      my @pad = (($cv->PADLIST->ARRAY)[1]->ARRAY); # depth=1?
      #diag "cv ",ref($cv)," (",$cv->flagspv,")";
      #my $s = ""; 
      #for my $p (@pad) {$s .= ref($p) =~ /B::?V*/ ? $p->sv : $p};
      #diag "pad ",@pad,": ",$s;
      $x = $cv->START;
      while ($$x) {
        if ($x->type == $const) {
          # see op.h:cSVOPx_sv
	  #my $sv = !${$x->sv} ? $pad[$x->targ] : $x->sv;
	  my $sv = $pad[$x->targ];
	  #my $sv = (ref $x->sv =~ /^B::(NULL|SPECIAL)$/) ? $pad[$x->targ] : $x->sv;
	  if ($DEBUG) {
	    diag "const ",ref($x); #," (",$x->flagspv,") ",$x->privatepv;
	    diag "const->sv ",ref($x->sv);
            my $val = ref($sv) eq 'B::SPECIAL' ? ["Null", "sv_undef", "sv_yes", "sv_no"]->[${$sv}]
              : (ref($sv) eq 'B::NULL' ? 'undef' : $sv->sv);
            diag "pad[",ref $sv," ",$val,"]/t",$x->targ;
	  }
	  if ( ref($sv) =~ /^B::PV/ and $sv->sv eq 'lead' ) {
	    diag $x->sv("gold", \&foo::baz); # may fail
	    diag "changed 'lead' into 'gold'";
	    last;
	  }
        }
	# $x->dump if $DEBUG;
	last unless $x->can('next');
	$x = $x->next;
      }
    } else {
      for($x = svref_2object(\&foo::baz)->START;
	  ref($x) ne 'B::NULL';
	  $x = $x->next
	 ) {
        # $x->dump if $DEBUG;
	next unless $x->can('sv') and $x->sv->can('PV');
	if ($x->sv->PV eq "lead") {
	  diag "changed 'lead' into 'gold'";
	  $x->sv("gold");
	  last;
	}
      }
    }
}

foo::baz();

{
  my $x = svref_2object(\&foo::baz);
  my $op = $x->START;
  my $y = $op->find_cv();
  $] < 5.010
    ? is($x->ROOT->seq, $y->ROOT->seq, "find_cv seq")
    : is(${$x->ROOT}, ${$y->ROOT}, "find_cv");
}

{
    my $foo = "hi";
    my $x = svref_2object(\$foo);
    is($x->PV, "hi", 'svref2object');

    $x->PV("bar");
    is($x->PV, "bar", 'changing the value of a PV');
    is($foo, "bar",   'and the associated lexical changes');
}
