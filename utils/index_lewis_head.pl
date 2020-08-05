#!/usr/bin/env -S perl -w
use strict;

my $i = 0;

while (<>) {
    if (m/<(?:entryFree|div1)[^>]*key\s*=\s*\"([^"]*)\"/)
    {
        my $head = $1;

        $head =~ s/[^a-zA-Z]//g;
        $head =~ tr/A-Z/a-z/;
        print "$head $i\n";
    }
    $i += length $_;
}
