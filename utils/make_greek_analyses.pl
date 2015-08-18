#!/usr/bin/perl -w
# Bug: doesn't seem to be outputing definitions properly yet
use strict;
use FindBin qw($Bin);
use File::Spec::Functions qw(catdir);

# use local CPAN
use lib (catdir($Bin, '..', 'dependencies', 'CPAN') );

use Search::Binary;

# [rtilde?]

my $usage = "Usage: $0 lsj-index.txt lsj-index-head.txt lsj-index-trans.txt < tlg.morph\n";

my $lsjfile = shift @ARGV or die $usage;
my $lsjheadfile = shift @ARGV or die $usage;
my $lsjtransfile = shift @ARGV or die $usage;

my %lsj;
open LSJX, "<$lsjfile" or die $!;
while (<LSJX>) {
    if (m/^(\S+)\s+(\S+)$/) {
        my $l = $1; my $o = $2;
        $lsj{$l} = $o;
    }
}
close LSJX;

my @lsj;
open HEAD, "<$lsjheadfile" or die $!;
while (<HEAD>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        push @lsj, $_;
    }
}
close HEAD;

my %trans;
open TRANS, "<$lsjtransfile" or die $!;
while (<TRANS>) {
    chomp;
    if (m/^(\d+)\s+(.+)$/) {
        $trans{$1} = $2;
    }
}
close TRANS;

my $old_pos;
my $read = sub {
    my ($handle, $val, $pos) = @_;
    unless (defined $pos) {
        $pos = $old_pos + 1;
    }
    my $rec = $lsj[$pos];
    $old_pos = $pos;
    my $result = compare($val, $rec);
    my @ret = ($result, $pos);
    return @ret;
};

# v is digammma
my @alphabet = qw(a b g d e v z h q i k l m n c o p r s t u f x y w);
my %alph;
my $i = 1;
for (@alphabet) {
    $alph{$_} = $i;
    $i++;
}

sub proximity {
    my $target = shift;
    $target =~ s/[^a-z]//g;
    # the - 2 is -1 for zero-terminated list size, and -1 as old_pos may overrun in read
    my $pos = binary_search(0, (scalar @lsj) - 2, $target, $read, undef, 1);
    my $hit = $lsj[$pos];
    return $hit
}


sub compare {
    my ($a, $b) = @_;
    $a =~ s/ .*$//;
    $b =~ s/ .*$//;
    my $min = (length $a < length $b) ? length $a : length $b;
    for ($i = 0; $i < $min; $i++) {
        my $aa = substr $a, $i, 1;
        my $bb = substr $b, $i, 1;
        die "error: $aa, $bb" unless (exists $alph{$aa} and exists $alph{$bb});
        return 1  if $alph{$aa} > $alph{$bb};
        return -1 if $alph{$aa} < $alph{$bb};
    }
    return 1  if length $a > length $b;
    return -1 if length $a < length $b;
    return 0;
}

my %rough_combos = (t => "q", p => "f", k => "x");

while (<>) {
    my $form = $_;
    chomp $form;
    my $nl = <>;
    die "Error 1" unless $nl;
    chomp $nl;
    die "Error 2" unless $nl =~ m#^<NL>.*</NL>$#;
    my @analyses = ();
    my %seen = ();
    my $line_out = "$form\t";
    while ($nl =~ m#<NL>(.*?)</NL>#g) {
        my $anal = $1;
        my $normal = $anal =~ m#(^[A-Z]) (\S+)  ([^\t]+)\t([^\t]+)?#;
        my ($part, $lemma, $inflect, $dialect) = ($1, $2, $3, $4);
        my $indecl;
        my $conf = 9;
        unless ($normal) {
            my $extra;
            $indecl = $anal =~ m#(^[A-Z]) (\S+) \t\t?([^\t]+)\t([^\t]+)?\t?([^\t]+)?#;
            ($part, $lemma, $inflect, $dialect, $extra) = ($1, $2, $3, $4, $5);
            $dialect .= " $extra" if $extra;
        }
        if (!$normal and !$indecl) {
            print STDERR "No match for $form\n$anal\n";
            next;
        }
        if(!defined $part && !defined $lemma && !defined $inflect) {
            print STDERR "->$anal\n";
            next;
        }
        my $info = $dialect ? "$inflect ($dialect)" : "$inflect";

        # The analysis can be either a single lemma or a
        # comma-separated list.  If the former and the form is not
        # hyphenated, then it's the analysis and is a lemma in LSJ
        # (though the LSJ entry may have vowel length marked in a way
        # that the analysis may not).  This includes compound verbs
        # that happen to have an LSJ entry.  If it is hyphenated, then
        # the compound form does not have an LSJ entry and we have to
        # look up both parts.  If it's a list, then it may be that we
        # have a multiple compound like this:
        # prefix,prefix,prefix-stem.  But this is complicated by the
        # fact that the first element of the list may be a
        # clarification of the form to be analysed: it might add what
        # was elided at the beginning or end, or clarify the quantity
        # of vowels.  So, in the case that the final form is
        # hyphenated, we need a heuristic to guess if the first item
        # in the list is part of the compound or not.

        # Note that in some cases, Morpheus reports as a hyphenated
        # compound a word that does have an entry in LSJ:
        # e.g. su/n-perigra/fw when there is an entry for
        # sumperigra/fw

        my $real_lemma;
        my @suppl_lemmata;
        if ($lemma !~ m/-/ and $lemma !~ m/,/) {
            $real_lemma = $lemma;
        } elsif ($lemma =~ m/-/ and $lemma !~ m/,/) {
            $lemma =~ m/^(.+)-(.+)$/;
            $suppl_lemmata[0] = $1;
            $real_lemma = $2;
        } elsif ($lemma !~ m/-/ and $lemma =~ m/,/) {
            $real_lemma = $lemma;
            $real_lemma =~ s/^.*,\s*//;
        } elsif ($lemma =~ m/-/ and $lemma =~ m/,/) {
            @suppl_lemmata = split /[,\s]+/, $lemma;
            $real_lemma = pop @suppl_lemmata;
            $real_lemma =~ m/^(.+)-(.+)$/;
            push @suppl_lemmata, $1;
            $real_lemma = $2;

            my $f1 = $suppl_lemmata[0];
            my $f2 = $form;
            $f1 =~ s/[\\\/=+]//g;
            $f2 =~ s/[\\\/=+]//g;
            if (($f1 eq $f2) or
                (length $f1 > 4 and substr $f1, 1, -1 eq substr $f2, 1, -1)) {
                # The first sub-part is not part of the compound
                shift @suppl_lemmata;
            }
        }
        else {
            die "Flow error!";
        }
        if (!$real_lemma) {
            print STDERR "Lemma? $lemma\n";
            next;
        }

        $conf=9;

        unless ($lsj{$real_lemma}) {
            # try without long/short vowel markers
            $conf = 7;
            $real_lemma =~ s/[_\^]//g;
        }
        unless ($lsj{$real_lemma}) {
            # try lower-case
            $conf=6;
            $real_lemma =~ s/\*//g;
        }
        unless ($lsj{$real_lemma}) {
            # try no numbers
            $conf=5;
            $real_lemma =~ s/\d$//g;
        }
        unless ($lsj{$real_lemma}) {
            # last-ditch effort -- no accents
            $conf=2;
            $real_lemma =~ s/[\\\/=|]//g;
        }
        unless ($lsj{$real_lemma}) {
            # real last-ditch effort -- no breathings
            $conf=1;
            $real_lemma =~ s/[()]//g;
        }

        my $trans = ' ';
        if ($conf > 4 and exists $trans{$lsj{$real_lemma}}) {
            $trans = $trans{$lsj{$real_lemma}}
        }

        if ($lsj{$real_lemma}) {
            $line_out .= "{$lsj{$real_lemma} $conf $lemma\t$trans\t$info}";
        } else {
            # desperation -- where it would appear, alphabetically.
            my $pos = proximity($real_lemma);
            $pos =~ s/^\S+ //;
            $line_out .= "{$pos 0 $lemma\t$trans\t$info}";
        }
        if (@suppl_lemmata) {
            for (@suppl_lemmata) {
                if ($lsj{$_}) {
                    $line_out .= "[$lsj{$_}]";
                }
            }
        }
        $seen{$info} = 1;
    }
    print $line_out."\n";
}
