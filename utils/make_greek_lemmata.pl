#!/usr/bin/perl -w
# TODO: read wordlist from extracted wordlist rather than tlgwlist.inx
use strict;

my $usage = "Usage: $0 index.txt tlgdir < analyses.txt\n";

my $indexfile = shift @ARGV or die $usage;
my $tlgdir = shift @ARGV or die $usage;

my %dict_ref;
open INDEX, "<$indexfile" or die $!;
while (<INDEX>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        $dict_ref{$1} = $2;
    }
}
close INDEX;

my %wlist;
$wlist{"\L$_"}++ for split /[\x80-\xff]/, `cat $tlgdir/tlgwlist.inx`;

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
        # for Greek, remove everything but the stem,
        # which is the only thing that will be in the dict.
        $stem =~ s/.*-//;

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
    $form = lower_case($form);
    while ($anl =~ m/{([^\}]+)}(?:\[[^\]]+\])*/g) {
        my $entry = $1;
        if ($entry =~ m/^(\d+) (\d) (.*?)\t(.*?)\t(.*?)$/) {
            my ($dict, $conf, $lemma, $trans, $info) = ($1, $2, $3, $4, $5);

            $lemma = munge_greek_lemma($lemma, $form);

            $lemma = lower_case($lemma);
            
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

sub lower_case {
    my $inp = shift;
    my $out = '';
    my @parts = split /([,-])/, $inp;
    for my $part (@parts) {
        if ($part =~ m/[,-]/) {
            $out .= $part;
        } else {
            $out .= lower_case_helper($part);
        }
    }
    return $out;
}

sub lower_case_helper {
    my $word = shift;
    
    # Perseus error
    $word = "*(=wrai" if $word eq "*=(wrai";

    return $word unless $word =~ m/^[^a-z]*\*/;
    if ($word =~ m/^\*([a-z].*)$/) {
        return $1;
    }
    if ($word =~ m/^\*([\\\/=|)(]+)([aeiouhw])(.*)$/) {
        print STDERR "$2$1\n" if $word eq "*)/|asoi";
        return "$2$1$3" if exists $wlist{"$2$1$3"} or exists $dict_ref{"$2$1$3"}; 
    }
    if ($word =~ m/^\*([\\\/=|)(]+)([aeiouhw][aeiouhw])(.*)$/) {
        return "$2$1$3" if exists $wlist{"$2$1$3"} or exists $dict_ref{"$2$1$3"}; 
    }
    # Sometimes Morpheus throws up a lemma that is not in the word-list.
    print STDERR "Guessing at lower-case of $word -- ";
    $word =~ s/^\*([\\\/=|)(]+)([aeiouhw]+)(.*)$/$2$1$3/;
    print STDERR " $word\n";
    return $word;
}

sub munge_greek_lemma {
    my $lemma = shift;
    my $form = shift;
    # See make_greek_analyses.pl for logic
    if ($lemma !~ m/-/ and $lemma =~ m/,/) {
        $lemma =~ s/^.*,\s*//;
    } elsif ($lemma =~ m/-/ and $lemma =~ m/,/) {
        $lemma =~ m/^(.+?),/;
        my $f1 = $1;
        my $f2 = $form;

        $f1 =~ s/[\\\/=+_^]//g;
        $f2 =~ s/[\\\/=+_^]//g;

        $f1 = substr $f1, 1, -1; 
        $f2 = substr $f2, 1, -1; 

        if (($f1 eq $f2) or
            (length $f1 > 4 and substr $f1, 1, -1 eq substr $f2, 1, -1)) {
            # The first sub-part is not part of the compound
            $lemma =~ s/^(.+?),//;
        }
    }
    return $lemma;
}
