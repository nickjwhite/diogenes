#!/usr/bin/perl -w
use strict;

open my $gc, "<gcide.dict" or die $!;
my $cur = '';
my $n = 1;
my $entry;
while (<$gc>) {
    chomp;
    if (m/^(\S+)/) {
        my $hw = $1;
        if ($hw eq $cur) {
            s/^/\t/;
        }
        else {
            $cur = $hw;
            print "\n", $entry if $entry;
            $entry = '';
        }
    }
    else {
        s/^(\s+)/\t$1/;
    }
    $entry .= $_
}
print $entry;
print "\n";
