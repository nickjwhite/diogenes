#!/usr/bin/perl -w
use strict;

binmode(STDIN);
binmode(STDERR, ":utf8");

use Encode;
use FindBin qw($Bin);
use File::Spec::Functions qw(:ALL);
use lib ($Bin, catdir($Bin, '..', 'server') );
use Diogenes::UnicodeInput;
my $d = new Diogenes::UnicodeInput;

my $i = 0;
my %seen;

while (<>) {
    if (m/<(?:entryFree|div2)[^>]*key\s*=\s*\"(.*?)\"/)
    {
        my $key = $1;
        print_variants($key);
        $key =~ s/[^a-z]//g;
        while (m/<(orth|head)\s*[^>]*>([^<]+)<\/(?:orth|head)>/g) {
            my $tag = $1;
            my $var = $2;
            $var =~ s/&lt;//gi;
            $var =~ s/&gt;//gi;
            $var =~ s/^—//gi;
            # Back-convert for Logeion dict.
            if ($var =~ m/[\x80-\xff]/ and utf8::decode($var)) {
                $var = $d->unicode_greek_to_beta($var);
                next if $var eq '0';
                $var = lc($var);
            }
            # Error in both LSJs
            next if ($key eq 'fakos' and $var eq 'o( ');
            next if ($key eq 'gunaikeios' and $var eq 'ko/lpos');
            print_variants($var);
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
