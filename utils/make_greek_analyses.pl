#!/usr/bin/perl -w
use strict;
use Data::Dumper;

# [rtilde?]

my %lsj;
open LSJX, "<lsj-index.txt" or die $!;
while (<LSJX>) {
    if (m/^(\S+)\s+(\S+)$/) {
        my $l = $1; my $o = $2;
        $lsj{$l} = $o;
    }
    else {
#         print $_;
    }
}
close LSJX;

my @lsj;
open HEAD, "<lsj-index-head.txt" or die $!;
while (<HEAD>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        push @lsj, $_;
    }
    else {
#         print $_;
    }
}
close HEAD;

my %trans;
open TRANS, "<lsj-index-trans.txt" or die $!;
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
    my $rec = $lsj[$pos];
    $old_pos = $pos;
    my $result = compare ($val, $rec);
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

use Search::Binary;
sub proximity {
    my $target = shift;
    $target =~ s/[^a-z]//g;
    my $pos = binary_search(0, (scalar @lsj), $target, $read, undef, 1);
    my $hit = $lsj[$pos];
#     print ">>$hit\n";
    return $hit
}


sub compare {
    my ($a, $b) = @_;
    $a =~ s/ .*$//;
    $b =~ s/ .*$//;
#     print "$a|$b|\n";
    my $min = (length $a < length $b) ? length $a : length $b;
    for ($i = 0; $i < $min; $i++) {
        my $aa = substr $a, $i, 1;
        my $bb = substr $b, $i, 1;
        die "error: $aa, $bb" unless (exists $alph{$aa} and exists $alph{$bb});
#         print "$aa, $bb, $alph{$aa}, $alph{$bb}\n";
        return 1  if $alph{$aa} > $alph{$bb};
        return -1 if $alph{$aa} < $alph{$bb};
    }
    return 1  if length $a > length $b;
    return -1 if length $a < length $b;
    return 0;
}

my %rough_combos = (t => "q", p => "f", k => "x");

open TLG, "<tlg.morph" or die $1;
open OUT, ">greek-analyses-unsorted.txt" or die $1;
while (<TLG>) {
    my $form = $_;
    chomp $form;
    my $nl = <TLG>;
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
        die "No match for $form\n$anal\n" unless $normal or $indecl;
        die ("->$anal\n") unless defined $part and defined $lemma and defined $inflect;
        my $info = $dialect ? "$inflect ($dialect)" : "$inflect";
#         print "$form -> $info\n"
#         push @analyses, $info unless $seen{$info};

#         $real_lemma =~ s/^.*,\s*//;

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
        die "Lemma? $lemma\n" unless $real_lemma;

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
#             print "#$real_lemma $lemma\n";
            my $pos = proximity($real_lemma);
            $pos =~ s/^\S+ //;
            $line_out .= "{$pos 0 $lemma\t$trans\t$info}";
#             print $line_out."\n";
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
    print OUT $line_out."\n";
#      print $line_out."\n";
}
close TLG or die $!;
close OUT or die $!;
# exit;


# print "?";
# my $in = <>;
# chomp $in;
# print ">$in\n";
# proximity($in);
# exit;




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
        o => 'greek-analyses.txt', I => 'greek-analyses-unsorted.txt'
    });

1;

#         unless ($lsj{$real_lemma}) {
#             # desperation -- where it would appear, alphabetically.
#             my $match;
#             for (my $i=3; $i< length $reserve_lemma; $i++) {
#                 my $try = substr $reserve_lemma, 0, $i;
#                 if ($lsj{$try}) {
#                     $real_lemma = $try;
#                 }
#             }
#         }









        # the lemma sometimes is a comma-separated list
#         my $real_lemma = $lemma;
#         $real_lemma =~ s/^.*,\s*//;
        # hyphenated compounds sometimes exist unhyphenated in LSJ,
        # but sometimes we make do with the last part
#         if ($real_lemma =~ m/^(.+)-(.+)$/) {
#             $conf=7;
#             my $start = $1;
#             my $end = $2;

#             $real_lemma = $start.$end;

#             unless ($lsj{$real_lemma}) {
#                 $real_lemma =~ s/^(.*[\(\)].*)[\(\)](.*)$/$1$2/; # remove dupl breathings
#                 $real_lemma =~ s/^(.*[\\\/=].*)[\\\/=](.*)$/$1$2/; # remove dupl accents (end)
#             }
#             unless ($lsj{$real_lemma}) {
#                 $real_lemma = $start.$end;
#                 $real_lemma =~ s/^(.*[\(\)].*)[\(\)](.*)$/$1$2/; # remove dupl breathings
#                 $real_lemma =~ s/^(.*)[\\\/=](.*[\\\/=].*)$/$1$2/; # remove dupl accents (front)
#             }
#             unless ($lsj{$real_lemma}) {
#                 $real_lemma = $start.$end;
#                 if ($end =~ m/^[aeiouhw]*\(/) {
#                     $start =~ m/(.)$/;
#                     my $tail = $1;
#                     if ($rough_combos{$tail}) {
#                         $start =~ s/(.)$//;
#                         $start .= $rough_combos{$tail};
#                         $end =~ s/^([aeiouhw]*)\(/$1/;
#                         $real_lemma = $start.$end;
#                         print "~$lemma $real_lemma\n";
#                     }
#                 }
#             }
#                     
#             if ($lsj{$real_lemma}) {
#                 print "($real_lemma $lemma)";
#             }
            
#             $real_lemma =~ s/^(.*[\\\/=].*)[\\\/=](.*)$/$1$2/; # remove dupl accents
#             $real_lemma =~ s/^(.*[\(\)].*)[\(\)](.*)$/$1$2/; # remove dupl breathings

#             unless ($lsj{$real_lemma}) {
#                 print "($real_lemma $lemma)";
#             }
#             my $start = $1;
#             my $end = $2;
#             my $orig_end = $end;
#             my @compound;
#             push @compound, $real_lemma;
#             push @compound, $start.$end;
#             $start =~ s/[\\\/=]//;
#             $end =~ s/([aeiouhw]+)\)/$1/;
#             push @compound, $start.$end;
#             push @compound, $orig_end;
#             for my $c (@compound) {
#             print ":$c\n";
#                 if (exists $lsj{$c}) {
#                     $real_lemma = $c;
#                     last;
#                 }
#             }
#         }
