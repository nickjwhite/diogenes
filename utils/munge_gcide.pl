#!/usr/bin/perl -w
use strict;

my $cur = '';
my $n = 1;
my $entry;
while (<>) {
    chomp;
    if (m/^(\S+)/) {
        my $hw = $1;
        if ($hw eq $cur) {
            s/^/\t/;
        } else {
            $cur = $hw;
            if($entry) {
                print "\n" if $n != 1;
                print $entry;
                $n++;
            }
            $entry = '';
        }
    } else {
        s/^(\s+)/\t$1/;
    }
    $entry .= $_;
}
print $entry;
print "\n";
