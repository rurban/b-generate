#!/usr/bin/perl -w
# RT #59502 Provokes error for B::Concise, B::Debug and B::Deparse
# https://rt.cpan.org/Ticket/Display.html?id=59502
# Fixed by Ben Morrow

use Test::More tests => 3;
BEGIN {
  use_ok 'B::Generate';
  use_ok 'B::Concise';
}

my $runperl = $^X =~ m/\s/ ? qq{"$^X"} : $^X;
my $redir = "2>&1" unless $^O eq 'MSWin32';
my $result = `$runperl -Mblib -MB::Generate -MO=Concise -e1 $redir`;
ok ($result !~ /locate object method "NAME"/, "RT 59502");
