#!/usr/bin/env -S perl -w
use strict;

my $i = 0;

while (<>) {
    if (m/<(?:entryFree|div1)[^>]*key\s*=\s*\"([^"]*)\"/)
    {
        if (/<sense [^>]*?>[^<]*<hi rend="ital">(.*?)<\/hi>/) {
            my $trans = $1;
            $trans =~ s/[,;:].*$//;
            # Many entries give orth and grammatical abbrs here
            unless ($trans =~ m/\./) {
                print "$i $trans\n";
            }
        }
    }
    $i += length $_;
}
