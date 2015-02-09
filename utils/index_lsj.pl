#!/usr/bin/perl -w
use strict;

my $i = 0;
my %seen;

while (<>) {
    my %orth;
    if (m/<entryFree[^>]*key\s*=\s*\"([^"]*)\"/)
    {
        my $key = $1;

        print_variants($key);
        $key =~ s/[^a-z]//g;
        while (m/<orth\s*[^>]*>([^<]+)<\/orth>/g) {
            my $orth = $1;
#             $orth =~ s/-//g;
            print_variants($orth);
        }
    }
    $i += length $_;
}

sub print_variants {
    my $key = shift;
    print_variants1($key);
    # remove asterisks
    if ($key =~ m/\*/) {
        $key =~ s/\*//g;
        # transpose any diacritics left dangling in front of lower-case
        $key =~ s/^([^a-z])([aeiouhw]+)/$2$1/;
        print_variants1($key);
    }
}

sub print_variants1 {
    my $key = shift;
    print_variants2($key);
    # remove hyphens
    if ($key =~ m/-/) {
        $key =~ s/-//g;
        print_variants2($key);
    }
}

sub print_variants2 {
    my $key = shift;
    print "$key $i\n" unless $seen{$key}++;
    # sometimes Morpheus just refers to a form without its number
    if ($key =~ m/\d$/) {
        $key =~ s/\d$//;
        print "$key $i\n" unless $seen{$key}++;
    }
    # sometimes Morpheus leaves out the long vowels and diaresis
    if ($key =~ m/[\^_+]/) {
        $key =~ s/[\^_+]//g;
        print "$key $i\n" unless $seen{$key}++;
    }
    # as a last resort for matching, print word without accents
    # (though with breathings)
    $key =~ s/[\\\/=|]//g;
    print "$key $i\n" unless $seen{$key}++;
    # desperation -- without breathings
    $key =~ s/[()]//g;
    print "$key $i\n" unless $seen{$key}++;
}
