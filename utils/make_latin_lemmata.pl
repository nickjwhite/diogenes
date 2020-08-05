#!/usr/bin/env -S perl -w
use strict;

my $usage = "Usage: $0 index.txt < analyses.txt\n";

my $indexfile = shift @ARGV or die $usage;

my %dict_ref;
open INDEX, "<$indexfile" or die $!;
while (<INDEX>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        $dict_ref{$1} = $2;
    }
}
close INDEX;

my (%lemmata, %dicts, %prefixes);

%lemmata = ();
%dicts = ();
%prefixes = ();
while (<>) {
    process($_);
}

scrub();

for my $key (sort keys %lemmata) {
    my $dict = $dicts{$key};
    if ($dict) {
        print "$key\t$dict\t";
    } else {
        my $stem = $key;
        # For Latin, just join the compound up, which should be in the dict
        $stem =~ s/^(.*)-(.*)$/$1$2/;
        $stem =~ s/#(\d)$//; # in-vulgo#2

        if ($dict_ref{$stem}) {
            print "$key\t$dict_ref{$stem}\t";
            print STDERR "Using $dict_ref{$stem} [$stem] for $key\n";
        } else {
            print "$key\t0\t";
            print STDERR "No dict for $key\n";
        }
    }
    # Consolidate duplicate forms
    my %forms = ();
    my @out = ();
    my $n = 0;
    for my $infl (@{ $lemmata{$key} }) {
        $infl =~ m/^(\S+)(.*)$/ or die "Bad infl: $infl -- $key\n";
        my ($form, $info) = ($1, $2);
        if (exists $forms{$form} ) {
            $out[$forms{$form}] .= $info;
        } else {
            $out[$n] = $infl;
            $forms{$form} = $n;
            $n++;
        }
    }
    print join "\t", @out;
    print "\n";
}

sub scrub {
    # If we still have any first segments and they are unique,
    # they are probably not prefixes
    my $min = 1000000;
    my $min_pre;
    for my $key (keys %lemmata) {
        if ($key =~ m/^(.*?),/) {
            my $pre = $1;
            if (exists $prefixes{$pre} and $prefixes{$pre} < 4) {
                print STDERR "Axing unique prefix: $pre\n";
                my $val = $lemmata{$key};
                delete $lemmata{$key};
                $key =~ s/^(.*),//;
                push @{ $lemmata{$key} }, @{ $val };
            }
            elsif (exists $prefixes{$pre} and $prefixes{$pre} <= 4) {
                print STDERR "Suspicious prefix: $pre\n";
            }
            if (exists $prefixes{$pre} and $prefixes{$pre} < $min and $prefixes{$pre} > 4) {
                $min = $prefixes{$pre};
                $min_pre = $pre;
            }
        }
    }
    print STDERR "Min prefix: $min_pre ($min)\n" if $min_pre;
}

sub process {
    my $anl = shift;
    my %seen;
    $anl =~ s/^([^\t]+)\t//;
    my $form = $1;
    return if $form =~ m/\!/;
    while ($anl =~ m/{([^\}]+)}(?:\[[^\]]+\])*/g) {
        my $entry = $1;
        if ($entry =~ m/^(\d+) (\d) (.*?)\t(.*?)\t(.*?)$/) {
            my ($dict, $conf, $lemma, $trans, $info) = ($1, $2, $3, $4, $5);

            $lemma = munge_latin_lemma($lemma);

            if ($lemma =~ m/^(.*),/) {
                $prefixes{$1}++;
            }

            my $infl = "$form ($info)";
            if (not $seen{$infl}) {

                if ($dicts{$lemma} and $dict != $dicts{$lemma}) {
                    # Should generally be LSJ with otherwise identical
                    # lower- and upper-case entries
                    print STDERR "Conflicting lemma: $lemma $dict $dicts{$lemma}\n"
                }
                $dicts{$lemma} = $dict unless $dicts{$lemma};
                push @{ $lemmata{$lemma} }, $infl;
                $seen{$infl}++;
            }
        } else {
            warn "Bad analysis: $entry";
        }
    }
}

sub munge_latin_lemma {
    my $lemma = shift;
    $lemma =~ s/^.*,\s*//;

    # the lemma has qui#1, while lewis has qui1
    $lemma =~ s/#(\d)$/$1/;

    # Hyphenated compounds should just be joined together --
    # unlike Greek, all compounds should be in the dict.
    if ($lemma =~ m/^(.+)-(.+)$/) {
        my $lemma = $1 . $2;
    }
    return $lemma;
}
