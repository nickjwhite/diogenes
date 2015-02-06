#!/usr/bin/perl -w
use strict;

open LEWIS, "<1999.04.0059.xml" or die $1;
open OUT, ">lewis-index.txt" or die $1;
open HEAD, ">lewis-index-head.txt" or die $1;
open TRANS, ">lewis-index-trans.txt" or die $1;

my $i = 0;
my %seen;

while (<LEWIS>) {
    my %orth;
    if (m/<entryFree[^>]*key\s*=\s*\"([^"]*)\"/)
    {
        my $key = $1;
#         print "$key \n";
        my $head = $key;
        $head =~ s/[^a-zA-Z]//g;
        $head =~ tr/A-Z/a-z/;
        print HEAD "$head $i\n";

        print OUT "$key $i\n"  unless $seen{$key}++;

        my $no_num = $key;
        $no_num =~ s/#?\d//;
        print OUT "$no_num $i\n"  unless $seen{$no_num}++;

        my $no_diacrits = $key;
        $no_diacrits =~ s/[\^_+]//g;
        print OUT "$no_diacrits $i\n" unless $seen{$no_diacrits}++;

        my $no_num_or_diacrits = $key;
        $no_num_or_diacrits =~ s/[\^_+]//g;
        print OUT "$no_num_or_diacrits $i\n" unless $seen{$no_num_or_diacrits}++;
        
        $key =~ s/[^a-zA-Z]//g;
        print OUT "$key $i\n" unless $seen{$key}++;

        if (m/<sense [^>]*?>[^<]*<hi rend="ital">(.*?)<\/hi>/) {
            my $trans = $1;
            $trans =~ s/[,;:].*$//;
            # Many entries give orth and grammatical abbrs here
            unless ($trans =~ m/\./) {
                print TRANS "$i $trans\n";
            }
        }

    }
    $i += length $_;
    
}

close LEWIS or die $!;
close OUT or die $!;
1;
