#!perl

# package BTest;
# pseudo-package, like test.pl, pollutes namespace.  This is currently
# necessary to call Test::More functions (maybe just use it, wo plan)

# goal is to write a main thats simple enough to inspect, then do so
# using B-Gen (B too?), and verify various op details

use B;
use B::Concise;
use Devel::Peek;

my %clsmap =
    (
     '0' =>	'OP',
     '1' =>	'UNOP',
     '2' =>	'BINOP',
     '|' =>	'LOGOP',
     '@' =>	'LISTOP',
     '/' =>	'PMOP',  
     '$' =>	'SVOP',  
     '"' =>	'PVOP',
     '{' =>	'LOOP',    
     ';' =>	'COP',,
     '#' =>	'PADOP',
    );

BEGIN {
    print "$_ => $clsmap{$_}\n" for keys %clsmap;
}


sub testop {
    # test that $op can execute methods given as keys in %args.

    my ($op, %args) = @_;

    if ($args{bcons}) {
	# get testable stuff by parsing B::Concise line
	parse_bcons(\%args);
	pass($args{bcons}); # annotation
    } else {
	warn "things depend on having B::Concise,-exec line";
    }
    
    # later, we'll emit the low-level code
    if ($args{emit}) {
	diag( "auto-gen'd, needs massaging\n",
	      "testop(\$op,\n",
	      map("\t $_ \t=> '$args{$_}',\n", 
		  sort keys %args),
	      "\t);\n");
    }
    
    my $label = $args{label} || $args{name};

    if ($args{ref}) {
	ok(ref $op eq $args{ref}, "$label isa ". $op);
    } else {
	# show reftype wo test, pls convert cases
	ok(1, "is a " . $op); # ref $op);
    }

    delete @args{qw/ arg bcons ref pass label to class emit /};

    # each key is a method on $op, so run them,
    # test retval against key's value (and type)
    for my $k (sort keys %args) {

	if (ref $args{$k} eq "CODE") {
	    # inspect the property with the code
	    my $res = eval { $args{$k}->($op->$k) };
	    #my $res = $args{$k}->($op->$k);
	    ok(!$@, "$label->$k()$res $@");
	}
	elsif (ref $args{$k} eq "Regexp") {
	    like( $op->$k, $args{$k},
		  "$label->$k is like $args{$k}" );
	}
	elsif (ref $args{$k} eq "ARRAY") {
	    # actual value in
	    ok( grep( $op->$k() eq $_, @{$args{$k}}),
		"$label->$k in @{$args{$k}}" );
	}
	elsif (defined $args{$k}) {
	    is( $op->$k(), $args{$k},
		"$label->$k is $args{$k}" );
	}
	else {
	    # method's return is unconstrained
	    ok( $op->$k(), "$label->$k is ok: ". $op->$k());
	}
    }

    # try various other methods, just to test stability/robustness
    for my $k (qw( sibling first last other children )) {
	next if $args{$k}; # already did it	
	if (my $do = $op->can($k)) {
	    ok ($op->$do, "$label->$k: ". $op->$do);
	}
    }
}

sub test_self_ops {
    my %args = @_;

    # called from a file-under-test, we get its B::Concise,-exec,-main
    # rendering, copy its exec-ops, and submit to test_all_ops

    my $walker = B::Concise::compile(qw( -exec -main -nobanner -src ));
    B::Concise::walk_output(\my $buf);
    $walker->('-main','-nobanner');
    diag("raw prog\n".$buf) if $args{-v} && $args{-v}>1;

    my @render = split /\n/, $buf;
    shift @render;

    # kludgy filter to exclude any branches
    @render = grep /^\w+\s{1,2}</, @render;
    diag(join "\n", "main op-vector", @render) if $args{-v};

    # KLUDGE - if B::Generate is 'used', B::Concise::compile() call
    # above fails badly:
    # Can't locate object method "NAME" via package "B::CV" at
    # /usr/local/lib/perl5/5.10.0/i686-linux-thread-multi/B/Concise.pm
    # line 831.

    eval "use B::Generate";

    # OTOH, if we dont require it here, we get failures in sv tests
    # because B returns B::SPECIAL objects rather than the B::SVOPs
    # that B::Generate returns, which respond 'properly' to ->sv()
    # methods

    my $start = B::main_start();
    my $next = $start;
    eval {
	do { push @exe, $next }
	while ($next = $next->next);
	# eventually dies on B::NULL
    };

    while (1) {
	my $op = shift @exe;
	my $ln = shift @render;
	last unless $op and $ln;
	testop($op, bcons => $ln, emit => $args{-v});
    }
}


sub istrue { (shift) }

sub parse_bcons {
    # digest B::Concise,-exec line, populate \%args with tests
    my $tests = shift;
    
    my $line = $tests->{bcons};
    my ($cls, $nm, $arg, $flg, $to);

    $tests->{to} = $1	if $line =~ s/\s*->(.*)$//;
    $tests->{arg} = $1	if $line =~ s/[\(\[](.+)[\]\)]//;

    # parse normalized line now
    (undef, $cls, $long, $flg) = split /\s+/, $line;

    $cls =~ /<(.)>/ && do {
	# convert <.> into 'B::*OP'
	$tests->{ref} = 'B::'.$clsmap{$1}
    };
    $long =~ s/^(\w+)// && do {
	$tests->{name}	//= $1;
	$tests->{label}	//= $1;
	$tests->{arg}	//= $long;
    };
    
    # parse pub-flags
    if ($flg) {
	my ($pub,$priv) = split m|/|, $flg;
	$_ = $pub;
	/v/  && do { $tests->{flags} |= &B::OPf_WANT_VOID };
	/s/  && do { $tests->{flags} |= &B::OPf_WANT_SCALAR };
	/l/  && do { $tests->{flags} |= &B::OPf_WANT_LIST };
	/K/  && do { $tests->{flags} |= &B::OPf_KIDS };
	/P/  && do { $tests->{flags} |= &B::OPf_PARENS };
	/R/  && do { $tests->{flags} |= &B::OPf_REF };
	/S/  && do { $tests->{flags} |= &B::OPf_STACKED };
	/M/  && do { $tests->{flags} |= &B::OPf_MOD };
	/\*/ && do { $tests->{flags} |= &B::OPf_SPECIAL };

	# check truth of privates (simple)
	$tests->{private} = \&istrue if $priv;
    }
    # parse '(arg)'
    if ($tests->{name} =~ /(next|db)state/) {

	# allow both 'nextstate' & 'dbstate'
	$tests->{name}	= qr/(next|db)state/;
	$tests->{label}	= 'nextstate';
	$tests->{type}	= [ B::opnumber('nextstate'),
			    B::opnumber('dbstate') ];

	# parse arg, collect more testable info
	my ($pkg, $num, $prog, $ln) = split /(?:\s+|:)/, $tests->{arg};
	$tests->{file} = qr/$prog/;
	$tests->{line} = $ln;
	# $tests->{filegv} = undef;	# no value constraint, just run it
    }
    elsif ($tests->{arg}) {
	# dig into args (for const ops)
	my ($t,$v) = split /\s+/, $tests->{arg};

	# behavior expected apriori
	# $tests->{sv} //= sub { "->$t \"".(shift)->$t() .'"' };

	$_ = $t;

	# anomalous IV,NV behavior
	# ie mismatch between bcons arg and tested obj
	
	/IV$/ && do {
	    $tests->{sv} //= sub { "->NV \"".(shift)->NV() .'"' };
	};
	/NV$/ && do {
	    $tests->{sv} //= sub { "->NV \"".(shift)->NV() .'"' };
	};
	/PV$/ && do {
	    $tests->{sv} //=
		sub {
		    my $sv = shift;
		    my $res;
		    ok($res = $sv->PV, "->PV $res");
		    ok($res = $sv->PVX, "->PVX $res");
		    ok($res = $sv->CUR, "->CUR $res");
		    ok($res = $sv->LEN, "->LEN $res");
		    Dump($sv) unless $res;
		    1;
	    };
	};
	/\*(w+)$/ && do {
	    diag ("found gv[$1]\n");
	    # $tests->{sv} //= sub { "->NV \"".(shift)->NV() .'"' };
	};
	/t(\d+)/ && do {
	    $tests->{targ} //= $1;
	};
    }
    $tests->{type} //= B::opnumber($tests->{name});
}


1;

__END__

=head1 NAME

BTest - helper for testing B module

=head1 SYNOPSIS

This module supports easy testing/torture of B module with a 2 layer
API.  The low-level function provides power, extensibility, and rope,
the high-level function provides ease of use by deriving OPs to test
from the test program itself.

    # Low Level API
    # test a single op by calling %tests keys as methods,
    # and comparing returned value to the stored value
    testop($op, %tests);

    # High Level API
    # test ops in main_start
    test_self_ops(-v => 2);

=head1 PURPOSE

B is a tricky yet foundational module which allows a sophisticated
user to inspect the optree of a perl program.  B is difficult to use
correctly, and prone to fatal errors otherwize.  It is also
undertested.

BTest's goals are to make -

    - it easy to do cursory testing of B on ops
    - it possible to do deeper tests (inspect op args)
    - easy stress testing
    - the test output self explanatory (tutorial value)
    - the tests look like specifications
    - tests are extensible
    - it easier to learn how to use B well
    - framework gives place to hang further knowledge/kludges

=head1 DESCRIPTION

BTest has a 2 level API which gives simplicity (test_self_ops) and
power (testop) in support of testing the B module.

=head2 test_self_ops(%args)

This function extracts the optree of the main program, and uses a
B::Concise rendering of it to determine runnable tests for each op,
and then run those tests.  This provides a baseline of coverage and
test sophistication which can improve over time.

It should be called from a file-under-test, immediately after some
main-code (ie not subroutine code).

NOTES:

Currently, we throw away any branches rendered by B::Concise, since
they are not part of the exec-order OP-vector.  Later, it may become
obvious how to use them.

=head2 testop($op, %tests)

testop examines $op, based upon user defined %tests.  Each key (aside
from special ones..) is invoked as an OP method C<< $op->$k() >>, and
the result is validated against $tests{$k}, in a manner based upon the
value's type:

    scalar - is()
    regexp - like()
    array  - grep { $retval eq $_ } @array
    undef  - call $op->$k(), dont test retval
    CODE   - call $code->($op->$k()), let code validate retval

This gives brevity and flexibilty, letting users run methods on one op
that would be inappropriate (or even segv!) on another.  Consider:

    testop($op,
       bcons   => 'a  <$> const[PV "1st thing in main"] sM',
       name    => 'const',
       flags   => &B::OPf_WANT_SCALAR | &B::OPf_MOD, # 32+2
       private => 0,
       type    => 5,
       sv      => sub { '->PV "'.(shift)->PV .'"' },
    );

Here, all keys (except bcons) are legitimate methods on $op, they're
each run and result is validated against values, typically something
like this:

    # f  <$> const[PV "1st thing in main"] sM 
    ok 99 - isa B::SVOP=SCALAR(0x8a32eec)
    ok 100 - const->flags is 34
    ok 101 - const->name is const
    ok 102 - const->private is 0
    ok 103 - const->sv()->PV "1st thing in main"
    ok 104 - const->type is 5

Some observations:

The bcons param is issued as a diagnostic message prior to the tests
being run.  This groups the tests visually.

Tests 100+ take the name param and use it as part of the test
description, giving an appearance of symbolic representation.

Test 99 gives "$op" rather than ref $op.  This prints the op's address
too, allowing user/tester to inspect linkage between ops.

One other thing not evident here - the test descriptions are
constructed from actual values returned by method calls.  This can be
confusing when the test fails and the description suggests otherwize.
However, doing so makes the descriptions more expressive and
informative when the test passes (the normal case).

=head3 sv => sub { '->PV "'.(shift)->PV .'"' },

Due to presence of this pair, testop() invokes C<< $code->($op->sv);
>>.  This particular callback fetches the string value, prefixed with
explanatory text (see above).

You have a lot of flexibility here; you can call any and all methods
of the object returned by the $op->method ('sv' here). and you can 


 - and enough rope to hang yourself.
If the constant was an integer, then ->PV would probably be bad.

NB: this sv example was developed to test B::Generate, which extends
B's API.  Im uncertain whether this example relys on the extensions.

Also, consider this example:

    testop($op2,
       bcons => 'e  <$> const[IV 1] sM ',
       sv => sub { "->NV ".(shift)->NV }, # ??? why NV not IV
       name => 'const',
       flags => &B::OPf_MOD | &B::OPf_WANT_SCALAR);

Here we have an anomaly (bug?) in that the B::Concise rendering says
'const[IV]', but the code that worked (and didnt crash!) was C<<
(shift)->NV >>, not C<< (shift)->IV >>

=head3 ref => 'B::OP'

This is the 1st special %test key; it's not treated as a method, but
rather as C<< ok(ref($op), $test{ref}, "isa $op") >>.

=head3 class => 'B::OP'

This is TBD, since B::class() fails when called as a method.

=head3 bcons => 'string'

This param is truly special - the value is parsed as a B::Concise
line, and a set of hypotheses are generated.  Each is stored in %tests
unless the caller has provided their own.  These new tests are then
run along with user provided ones.

Currently, at least the following tests are synthesized:

type - this pair is created by calling B::opnumber($tests{name}).
This is a round-trip test that is effectively predestined to pass, but
which exersizes B code more than otherwize.  A few tricks are played
here so that nextstate and dbstate are 'equivalent', which prevents
false failures when running under debugger.

ref - this is populated based upon a /<.>/ match on the bcons param.
The resulting test has little value, since it uses ref($op), not B
code.  It is however useful to reinforce the 1-many relationship
between op-class and op-type.

For nextstate ops, the arg is parsed, and file, line tests are added.

=head3 unspecified tests

Since one goal is to *bang* on B as much as possible, we also try
various B::*OP methods, protected by C<< $op->can($method) >>.  In
this example, the last 4 tests are done automatically:

    # t  <@> list vKPM/128
    ok 159 - list isa B::LISTOP=SCALAR(0xa271a2c)
    ok 160 - list->flags is 45
    ok 161 - list->name is list
    ok 162 - list->type is 142
    ok 163 - list->sibling: B::COP=SCALAR(0xa290bac)
    ok 164 - list->first: B::OP=SCALAR(0xa290bac)
    ok 165 - list->last: B::OP=SCALAR(0xa290bac)
    ok 166 - list->children: 3

These tests cannot fail, except by crashing, since no expected result
is available.  By running them automatically, we tacitly suggest that
they be converted to real tests.  Specifically, adding C<< children =>
3 >> to %tests will verify that there are really 3 kid ops.

=head3 testing siblings, first, last, other

With testop() its possible to test for proper linkage; given a fixed
array of ops in exec-order, and knowledge of the ops themselves:

  6     <1> entersub[t2] vKS/TARG,1 ->7
  -        <1> ex-list K ->6
  3           <0> pushmark s ->4
  4           <$> const[PV "B"] sM ->5

It should be possible to do something like:

    testop($op[3], 
	   bcons    => '<0> pushmark s ->4',
    	   sibling  => $op[4]);

Since pushmark never has kids, its sibling is also its next, and
should be testable.  CAVEAT - tests like this dont work yet TBD.

=head2 test_all_ops(\@ops, $rendering);

This mid-level function takes a B::Concise,-exec rendering, parses it
into lines, then calls testop($op, bcons => $line) to test each.  This
makes it easy to leverage testop's bcons handling.

It is used by test_self_ops(), which adds the ability to get the
rendering automatically.

Its weakness is that it hides testop's ability to incorporate
customized user tests.  An emit-source may be added to improve this.


=head1 Current Issues

=head2 anomalous IV,NV behavior

If you search the code for (heading), youll find code which attempts
to address a discrepancy between how bconcise renders OP_CONST args
(typically \[(IV|NV|PVIV) (\w)+\]) and what testing shows to be fatal.

TODO Either turn them into exception tests, or examine B::Concise to
see how its displaying/determining the type.

=head1 Future Development

=head2 more parse_bcons() refinements

refactor parse_bcons() op-specific processing, provide plug-on
test-subs modelled after anonymous subs probing object returned from
'->sv', 1st developed using testop.

=head2 follow branches

due to brain-dead op-vector build, we only get ops which are not on a
branch, excluding if blocks, for blocks, etc..

Consider a B::Concise callback, or 

=head2 sentinel

test_self_ops() could also act as a sentinel, whereby only main-code
prior to the call is used as B OP cannon-fodder.  OTOH, theres no
obvious reason why this is useful.

=cut
