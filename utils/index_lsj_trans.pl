#!/usr/bin/perl -w
use strict;

my $i = 0;

while (<>) {
    if (m/<div2[^>]*key\s*=\s*\"(.*?)\"/)
    {
        if (m/<i>(.*?)<\/i>/) {
            my $trans = $1;
            $trans =~ s/[,;:].*$//;
            print "$i $trans\n";
        }
    }
    $i += length $_;
}
