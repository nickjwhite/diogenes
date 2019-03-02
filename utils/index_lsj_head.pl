#!/usr/bin/perl -w
use strict;
binmode(STDIN);
binmode(STDERR, ":utf8");

my $i = 0;

while (<>) {
    if (m/<(?:entryFree|div2)[^>]*key\s*=\s*\"(.*?)\"/)
    {
        my $key = $1;
        $key =~ s/[^a-z]//g;

        unless ($key =~ m/^v/ or $key =~ m/j/) {
            # digamma -- out of order; no idea what j is
            print "$key $i\n";
        }
    }
    $i += length $_;
}
