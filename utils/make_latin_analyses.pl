#!/usr/bin/env -S perl -w
use strict;
use FindBin qw($Bin);
use File::Spec::Functions qw(catdir);

# use local CPAN
use lib (catdir($Bin, '..', 'dependencies', 'CPAN') );

use Search::Binary;

my $usage = "Usage: $0 lewis-index.txt lewis-index-head.txt lewis-index-trans.txt < lat.morph\n";

my $lsfile = shift @ARGV or die $usage;
my $lsheadfile = shift @ARGV or die $usage;
my $lstransfile = shift @ARGV or die $usage;

my %ls;
open LS, "<$lsfile" or die $!;
while (<LS>) {
    if (m/^(\S+)\s+(\S+)$/) {
        my $l = $1; my $o = $2;
        $ls{$l} = $o;
    }
}
close LS;

my @ls;
open HEAD, "<$lsheadfile" or die $!;
while (<HEAD>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        push @ls, $_;
    }
}
close HEAD;

my %trans;
open TRANS, "<$lstransfile" or die $!;
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
    my $rec = $ls[$pos];
    $old_pos = $pos;
    my $result = compare($val, $rec);
    my @ret = ($result, $pos);
    return @ret;
};

sub compare {
    my ($a, $b) = @_;
    $a =~ s/ .*$//;
    $b =~ s/ .*$//;
    return $a cmp $b;
}

sub proximity {
    my $target = shift;
    $target =~ s/[^a-z]//g;
    my $pos = binary_search(0, (scalar @ls), $target, $read, undef, 1);
    my $hit = $ls[$pos];
    return $hit
}


# Some odd word fragments that Morpheus peculiarly thinks it can parse.
my @bad = qw{etae etai etarum etas ete etene eti etidem etine etior etius eto eton etu etura etus eui euit evi evit};
my %bad;
$bad{$_}++ for @bad;


while (<>) {
    my $form = $_;
    chomp $form;
    my $nl = <>;
    die "Error 1" unless $nl;
    chomp $nl;
    die "Error 2" unless $nl =~ m#^<NL>.*</NL>$#;
    next if $bad{$form};

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

        # the lemma sometimes is a comma-separated list
        my $real_lemma = $lemma;
        $real_lemma =~ s/^.*,\s*//;

        # the lemma has qui#1, while lewis has qui1
        $real_lemma =~ s/#(\d)$/$1/;

        # Hyphenated compounds should just be joined together --
        # unlike Greek, all compounds should be in the dict.
        if ($real_lemma =~ m/^(.+)-(.+)$/) {
            my $real_lemma = $1 . $2;
        }
        unless ($ls{$real_lemma}) {
            # try without long/short vowel markers
            $conf = 5;
            $real_lemma =~ s/[_\^]//g;
        }

        unless ($ls{$real_lemma}) {
            # try lower-case
            $conf=4;
            $real_lemma =~ s/\*//g;
            $real_lemma =~ tr/A-Z/a-z/;
        }
        unless ($ls{$real_lemma}) {
            # last-ditch effort -- no analphabetics
            $conf=2;
            $real_lemma =~ s/[^a-zA-Z]//g;
        }

        my $trans = ' ';
        if ($conf > 4 and exists $trans{$ls{$real_lemma}}) {
            $trans = $trans{$ls{$real_lemma}}
        }

        if ($ls{$real_lemma}) {
            $line_out .= "{$ls{$real_lemma} $conf $lemma\t$trans\t$info}";
        } else {
            # desperation -- where it would appear, alphabetically.
            my $pos = proximity($real_lemma);
            $pos =~ s/^\S+ //;
            $line_out .= "{$pos 0 $lemma\t$trans\t$info}";
        }
        $seen{$info} = 1;
    }
    print $line_out."\n";
}
