#!/usr/bin/perl -w
use strict;

no locale;
# get constants
use POSIX 'locale_h';
$ENV{LC_ALL} = $ENV{LANG} = '';
# use new ENV settings
setlocale(LC_CTYPE, '');
setlocale(LC_COLLATE, '');

my %lsj;
open LSJ, "<lsj-index.txt" or die $!;
while (<LSJ>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        $lsj{$1} = $2;
    }
    else {
#         print $_;
    }
}
close LSJ;

my %ls;
open LS, "<lewis-index.txt" or die $!;
while (<LS>) {
    chomp;
    if (m/^(\S+)\s+(\S+)$/) {
        $ls{$1} = $2;
    }
    else {
#         print $_;
    }
}
close LS;

my %wlist;
$wlist{"\L$_"}++ for split /[\x80-\xff]/, `cat tlgwlist.inx`;

my (%lemmata, %dicts, %prefixes, $lang);

for my $file (qw(greek-analyses.txt latin-analyses.txt)) {
# for my $file (qw(greek-analyses.txt)) {
    open my $fh, "<$file" or die $!;
    %lemmata = ();
    %dicts = ();
    %prefixes = ();
    $lang = ($file =~ m/latin/) ? "l" : "g";
    while (<$fh>) {
        process($_);
    }
    close $fh or die $!;

    my $out_file = $file;
    $out_file =~ s/analyses/lemmata/;
    open $fh, ">$out_file" or die $!;
    scrub();
#     remove_uppercase_dups();

    for my $key (sort keys %lemmata) {

        my $dict = $dicts{$key};
        if ($dict) {
            print $fh "$key\t$dict\t";
        } else {
            my $stem = $key;
            # For Latin, just join the compound up, which should be in
            # the dict; for Greek, remove everything but the stem,
            # which is the only thing that will be in the dict.
            if ($lang eq "l") {
                $stem =~ s/^(.*)-(.*)$/$1$2/;
                $stem =~ s/#(\d)$//; # in-vulgo#2
            } else {
                $stem =~ s/.*-//;
            }
            my $dict_ref = ($lang eq "l") ? \%ls : \%lsj;
            if ($dict_ref->{$stem}) {
                print $fh "$key\t$dict_ref->{$stem}\t";
                print "Using $dict_ref->{$stem} [$stem] for $key\n";
            }
            else {
                print $fh "$key\t0\t";
                print "No dict for $key\n";
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
            }
            else {
                $out[$n] = $infl;
                $forms{$form} = $n;
                $n++;
            }
        }
#         print $fh join "\t", @{ $lemmata{$key} };
        print $fh join "\t", @out;
        print $fh "\n";
    }
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
                print "Axing unique prefix: $pre\n";
                my $val = $lemmata{$key};
                delete $lemmata{$key};
                $key =~ s/^(.*),//;
                push @{ $lemmata{$key} }, @{ $val };
            }
            elsif (exists $prefixes{$pre} and $prefixes{$pre} <= 4) {
                print "Suspicious prefix: $pre\n";
            } 
            if (exists $prefixes{$pre} and $prefixes{$pre} < $min and $prefixes{$pre} > 4) {
                $min = $prefixes{$pre};
                $min_pre = $pre;
            }
        }
    }
    print "Min prefix: $min_pre ($min)\n" if $min_pre;
}

# We run morpheus on both lower- and upper-case, since proper names
# and such will only be recognized if capitalized.  But for some
# reason, morpheus for some upper-cased un-proper words returns an
# upper-case parse.  We get rid of these, where the upper-case is a
# duplicate of the lower-case parse.  Most strangely, when these
# duplicate upper-case parses begin with a vowel, they have asterisk,
# then vowel, then accent/breathing.  

# We don't use this anymore.  We need to normalize inflected forms to
# lower-case anyway, in order to feed them into the TLG word-search

sub remove_uppercase_dups {
    my $n = 0;
KEY:
    for my $key (keys %lemmata) {
        if ($key =~ m/^\*(.*)$/) {
            my $lower = $1;
            if (exists $lemmata{$lower}) {
#                 print "Possible dup: $key $lower\n";
#                 print join " ", @{ $lemmata{$key} };
#                 print "\n\n ";
#                 print join "  ", @{ $lemmata{$lower} };
#                 print "\n\n\n";                
#                 $n++;
#                 if ($lower =~ m/^[)(\\\/=]/) {
#                     print "\n WARNING!! $lower appears to have accents correct!\n"
#                 }
INFL:
                for my $infl (@{ $lemmata{$key} }) {
                    if (grep {
                        my $x = "*$_";
                        my $y = $infl;
                        $x =~ s/ .*$//;
                        $y =~ s/ .*$//;
                        $x eq $y;
                        } @{ $lemmata{$lower} } ) {
                        next INFL;
                    }
                    print "$key has $infl but $lower does not -- keeping it\n";
                    next KEY;
                }
                print "Deleting duplicate upper-case $key\n";
                delete $lemmata{$key};
            }
        }
    }
#     print "N: $n\n";
}

sub process {
    my $anl = shift;
    my %seen;
#     $query = $beta_to_utf8->($query) if $lang eq 'grk';
    $anl =~ s/^([^\t]+)\t//;
    my $form = $1;
    return if $form =~ m/\!/;
    $form = lower_case($form) if $lang eq 'g';
    while ($anl =~ m/{([^\}]+)}(?:\[[^\]]+\])*/g) {
        my $entry = $1;
        if ($entry =~ m/^(\d+) (\d) (.*?)\t(.*?)\t(.*?)$/) {
            my ($dict, $conf, $lemma, $trans, $info) = ($1, $2, $3, $4, $5);

            if ($lang eq "l") {
                $lemma = munge_latin_lemma($lemma);
            } else {
                $lemma = munge_greek_lemma($lemma, $form);
            }
            $lemma = lower_case($lemma) if $lang eq 'g';
            
            if ($lemma =~ m/^(.*),/) {
                $prefixes{$1}++;
            }

            my $infl = "$form ($info)";
#             if ($conf > 1 and not $seen{$infl}) {
            if (not $seen{$infl}) {

                if ($dicts{$lemma} and $dict != $dicts{$lemma}) {
                    # Should generally be LSJ with otherwise identical
                    # lower- and upper-case entries
                    print "Conflicting lemma: $lemma $dict $dicts{$lemma}\n"
                }
                $dicts{$lemma} = $dict unless $dicts{$lemma};
                push @{ $lemmata{$lemma} }, $infl;
                $seen{$infl}++;
            }
        }
        else {
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
        }
        else {
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
        print "$2$1\n" if $word eq "*)/|asoi";
        return "$2$1$3" if exists $wlist{"$2$1$3"} or exists $lsj{"$2$1$3"}; 
    }
    if ($word =~ m/^\*([\\\/=|)(]+)([aeiouhw][aeiouhw])(.*)$/) {
        return "$2$1$3" if exists $wlist{"$2$1$3"} or exists $lsj{"$2$1$3"}; 
    }
    # Sometimes Morpheus throws up a lemma that is not in the word-list.
    print "Guessing at lower-case of $word -- ";
    $word =~ s/^\*([\\\/=|)(]+)([aeiouhw]+)(.*)$/$2$1$3/;
    print " $word\n";
    return $word;

    die "What is $word?\n";
    
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
#                 print ">$f1 $f2 \n";
        $f1 =~ s/[\\\/=+_^]//g;
        $f2 =~ s/[\\\/=+_^]//g;
#                  print ">$f1 $f2<\n";
        $f1 = substr $f1, 1, -1; 
        $f2 = substr $f2, 1, -1; 
#                     print ">>$f1 $f2<<\n";
        if (($f1 eq $f2) or
            (length $f1 > 4 and substr $f1, 1, -1 eq substr $f2, 1, -1)) {
            # The first sub-part is not part of the compound
#                      print "#$lemma ($form)\n";
            $lemma =~ s/^(.+?),//;
#                      print "#$lemma ($form)\n";
        }
#                 print "\$$lemma ($form)\n";
    }
    return $lemma;
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

1;

# sub remove_uppercase_dups {
# KEY:
#     for my $key (keys %lemmata) {
#         if ($key =~ m/^([^a-zA-Z])*\*(.*)$/) {
#             my $diacrits = $1;
#             my $lower = $2;
#             if ($diacrits) {
#                 $lower =~ s/^([\\\/=|)(]+)([aeiouhw])/$2$1/;
#                 if (not exists $lemmata{$lower}) {
#                     $lower =~ s/^([aeiouhw])([\\\/=|)(]+)([aeiouhw])/$1$3$2/;
#                     if (not exists $lemmata{$lower}) {
#                         next KEY;
#                     }
#                 }
#             }
#             else {
#                 if (not exists $lemmata{$lower}) {
#                     next KEY;
#                 }
#             }
# INFL:
#             for my $infl (@{ $lemmata{$key} }) {
#                 if (grep {$_ eq $infl} @{ $lemmata{$lower} } ) {
#                     next INFL;
#                 }
#                 print "$key has $infl but $lower does not -- keeping it\n";
#                 next KEY;
#             }
#             print "Deleting duplicate upper-case $key\n";
#             delete $lemmata{$key};
#         }
#     }
# }

