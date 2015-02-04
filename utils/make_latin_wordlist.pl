#!/usr/bin/perl -w
use strict;
my %words;
my $chars = "a-zA-Z/";

my $phidir = shift @ARGV or die "Usage: $0 phidir\n";
my @files;

opendir my $dir, $phidir or die $!;
# my @files = grep {/lat1020.txt/i} readdir $dir;
# my @files = grep {/lat0474.txt/i} readdir $dir;
for (readdir $dir) {
    next unless m/lat.+\.txt/i;
    next if m/lat9999.txt/i;
    push @files, "$phidir/$_";
}
closedir $dir;
push @files, "$phidir/civ0004.txt"; # vulgate

local $/;
for my $file (@files) {
    open my $fh, $file or die $!;
    while ($file = <$fh>) {
        while ($file =~ m/([$chars-]+)/g) {
            my $word = $1;
            if ($word =~ m/-$/) {
                $word =~ s/-$//;
                $file =~ m/[^$chars]+([$chars]+)/g;
                $word .= $1;
#                 print "$word\n";
            }
            $word =~ s/\///; # kill accents
            $word =~ tr/A-Z/a-z/ if $word =~m/^[A-Z]+$/; # all caps
            $words{$word}++;
            # For capitalized words, add lower-case, too.
            if ($word =~ m/^[A-Z][a-z]+$/) {
                $word =~ tr/A-Z/a-z/;
                $words{$word}++;
            }
        }
    }
    close $fh or die $!;
}

for my $word (sort keys %words) {
    print "$word\n"
}

