package B::Generate;

require 5.005_62;
use strict;
use warnings;
use B;

require DynaLoader;

our @ISA = qw(DynaLoader);

our $VERSION = '0.02';

{
no warnings;
bootstrap B::Generate $VERSION;
}

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

B::Generate - Create your own op trees. 

=head1 SYNOPSIS

    use B::Generate;
    # Do nothing, slowly.
      CHECK {
        my $null = new B::OP("null",0);
        my $enter = new B::OP("enter",0);
        my $cop = new B::COP(0, "hiya", 0);
        my $leave = new B::LISTOP("leave", 0, $enter, $null);
        $leave->children(3);
        $enter->sibling($cop);
        $enter->next($cop);
        $cop->sibling($null);
        $null->next($leave);
        $cop->next($leave);

        # Tell Perl where to find our tree.
        B::main_root($leave);
        B::main_start($enter);
      }

=head1 WARNING

! WARNING ! WARNING ! WARNING ! WARNING ! WARNING ! WARNING ! WARNING ! WARNING

C<B::Generate> is alpha-quality software. Large parts of it don't work.
Even the parts that B<do> work should give you the willies. 

Patches welcome.

=head1 DESCRIPTION

Malcolm Beattie's C<B> module allows you to examine the Perl op tree at
runtime, in Perl space; it's the basis of the Perl compiler. But what it
doesn't let you do is manipulate that op tree: it won't let you create
new ops, or modify old ones. Now you can.

Well, if you're intimately familiar with Perl's internals, you can.

C<B::Generate> turns C<B>'s accessor methods into get-set methods.
Hence, instead of merely saying

    $op2 = $op->next;

you can now say

    $op->next($op2);

to set the next op in the chain. It also adds constructor methods to
create new ops. This is where it gets really hairy.

    new B::OP     ( type, flags )
    new B::UNOP   ( type, flags, first )
    new B::BINOP  ( type, flags, first, last )
    new B::LOGOP  ( type, flags, first, other )
    new B::LISTOP ( type, flags, first, last )
    new B::COP    ( flags, name, first )

In all of the above constructors, C<type> is either a numeric value
representing the op type (C<62> is the addition operator, for instance)
or the name of the op. (C<"add">)

C<first>, C<last> and C<other> are ops to be attached to the current op;
these should be C<B::OP> objects. If you haven't created the ops yet,
don't worry; give a false value, and fill them in later:

    $x = new B::UNOP("negate", 0, undef);
    # ... create some more ops ...
    $x->first($y);

Finally, you can set the main root and the starting op by passing ops
to the C<B::main_root> and C<B::main_start> functions.

This module can obviously be used for all sorts of fun purposes. The
best one will be in conjuction with source filters; have your source
filter parse an input file in a foreign language, create an op tree for
it and get Perl to execute it. Then email me and tell me how you did it.
And why.

=head2 OTHER METHODS

=over 3

=item  $b_sv->sv

Returns a real SV instead of a C<B::SV>. For instance:

    $b_sv = $svop->sv;
    if ($b_sv->sv == 3) {
        print "SVOP's SV has an IV of 3\n"
    }

You can't use this to set the SV. That would be scary.

=item $op->dump

Runs C<Perl_op_dump> on an op; this is roughly equivalent to
C<B::Debug>, but not quite.

=item $b_sv->dump

Runs C<Perl_sv_dump> on an SV; this is exactly equivalent to
C<< Data::Dumper::dump($b_sv->sv) >>

=back

=head2 EXPORT

None.

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 SEE ALSO

L<B>, F<perlguts>, F<op.c>

=cut
