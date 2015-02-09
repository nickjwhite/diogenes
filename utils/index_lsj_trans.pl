#!/usr/bin/perl -w
use strict;

my $i = 0;

while (<>) {
    if (m/<entryFree[^>]*key\s*=\s*\"([^"]*)\"/)
    {
        if (m/<tr\s[^>]*>(.*?)<\/tr>/) {
            my $trans = $1;
            $trans =~ s/[,;:].*$//;
            print "$i $trans\n";
        }
    }
    $i += length $_;
}
