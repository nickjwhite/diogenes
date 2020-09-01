#!/usr/bin/env perl
use strict;
use warnings;

my $i = 0;
my %seen;

while (<>) {
    if (m/<(?:entryFree|div1)[^>]*key\s*=\s*\"([^"]*)\"/)
    {
        my ($key, $no_num, $no_diacrits, $no_num_or_diacrits, $basic_key);

        $key = $no_num = $no_diacrits = $no_num_or_diacrits = $basic_key = $1;

        $no_num =~ s/#?\d//;
        $no_diacrits =~ s/[\^_+]//g;
        $no_num_or_diacrits =~ s/[\^_+]//g;
        $basic_key =~ s/[^a-zA-Z]//g;

        print "$key $i\n" unless $seen{$key}++;
        print "$no_num $i\n" unless $seen{$no_num}++;
        print "$no_diacrits $i\n" unless $seen{$no_diacrits}++;
        print "$no_num_or_diacrits $i\n" unless $seen{$no_num_or_diacrits}++;
        print "$basic_key $i\n" unless $seen{$basic_key}++;
    }
    $i += length $_;
}
