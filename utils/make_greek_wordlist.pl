#!/usr/bin/perl -w
use strict;

my $tlgdir = shift @ARGV or die "Usage: $0 tlgdir\n";

my @words = split /[\x80-\xff]+/, `cat $tlgdir/tlgwlist.inx`;

for (@words) {
    s/[\x00]//g;
    tr[A-Z][a-z];
    next if m#^iaewbafrenemoun#;
    next if m#\!#;
    print "$_\n";
    # And try uppercase, too.
    print "*$_\n";
    print "*$_\n" if s/^([aeiouhw])([\\\/=|()]+)/$2$1/;
    print "*$_\n" if s/^([aeiouhw][aeiouhw])([\\\/=|()]+)/$2$1/;
}
