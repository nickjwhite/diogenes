#!/usr/bin/perl -w
use strict;
use Data::Dumper;

my %ls;
open LS, "<lewis-index.txt" or die $!;
while (<LS>) {
    if (m/^(\S+)\s+(\S+)$/) {
        my $l = $1; my $o = $2;
        $ls{$l} = $o;
    }
    else {
#         print $_;
    }
}
close LS;

my @ls;
open HEAD, "<lewis-index-head.txt" or die $!;
while (<HEAD>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        push @ls, $_;
    }
    else {
#         print $_;
    }
}
close HEAD;

my %trans;
open TRANS, "<lewis-index-trans.txt" or die $!;
while (<TRANS>) {
    chomp;
    if (m/^(\d+)\s+(.+)$/) {
        $trans{$1} = $2;
    }
    else {
#         print $_;
    }
}
close HEAD;

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
#     print "@ret :$val, $rec\n";
    return @ret;
};

sub compare {
    my ($a, $b) = @_;
    $a =~ s/ .*$//;
    $b =~ s/ .*$//;
#       print "$a|$b|\n";
    return $a cmp $b;
}

use Search::Binary;
sub proximity {
    my $target = shift;
    $target =~ s/[^a-z]//g;
    my $pos = binary_search(0, (scalar @ls), $target, $read, undef, 1);
    my $hit = $ls[$pos];
#     print ">>$hit\n";
    return $hit
}

# print "?";
# my $in = <>;
# chomp $in;
# my $p = proximity($in);
# print ">$p\n";
# exit;

# Some odd word fragments that Morpheus peculiarly thinks it can parse.
my @bad = qw{etae etai etarum etas ete etene eti etidem etine etior etius eto eton etu etura etus eui euit evi evit};
my %bad;
$bad{$_}++ for @bad;


open LAT, "<lat.morph" or die $1;
open OUT, ">latin-analyses-unsorted.txt" or die $1;
while (<LAT>) {
    my $form = $_;
    chomp $form;
    my $nl = <LAT>;
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
        die "No match for $form\n$anal\n" unless $normal or $indecl;
        die ("->$anal\n") unless defined $part and defined $lemma and defined $inflect;
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
#             print $line_out."\n";
        }
        $seen{$info} = 1;
    }
    print OUT $line_out."\n";
#      print $line_out."\n";
}
close LAT or die $!;
close OUT or die $!;
#  exit;


# install File::Sort from CPAN
use File::Sort qw(sort_file);
no locale;
# get constants
use POSIX 'locale_h';
$ENV{LC_ALL} = $ENV{LANG} = '';
# use new ENV settings
setlocale(LC_CTYPE, '');
setlocale(LC_COLLATE, '');

sort_file({
        t => "\t", k => 1,
        o => 'latin-analyses.txt', I => 'latin-analyses-unsorted.txt'
    });

1;
