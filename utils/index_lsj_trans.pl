#!/usr/bin/perl -w
use strict;
binmode(STDIN);
binmode(STDERR, ":utf8");

my $i = 0;

while (<>) {
    if (m/<(?:entryFree|div2)[^>]*key\s*=\s*\"(.*?)\"/)
    {
        if (m/<tr\s[^>]*>(.*?)<\/tr>/ or
            m/<sense\s[^>]*>.*?<i>(.*?)<\/i>/) {
            my $trans = $1;
            $trans =~ s/[,;:.]$//;
            print "$i $trans\n";
        }
    }
    $i += length $_;
}
