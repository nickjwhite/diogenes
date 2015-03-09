#!/usr/bin/perl -w
use strict;

my $i = 0;

while (<>) {
    if (/<tr\s[^>]*>(.*?)<\/tr>/) {
        my $trans = $1;
        $trans =~ s/[,;:].*$//;
        print "$i $trans\n";
    }
    $i += length $_;
}
