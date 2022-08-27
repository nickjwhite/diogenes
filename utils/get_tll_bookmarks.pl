#!/usr/bin/env perl
use strict;
use warnings;
use 5.012;
use autodie;
use File::Spec::Functions qw(:ALL);
use Getopt::Std;
use JSON;

# New script to get the TLL info from the JSON file they have provided.

getopts ('t:l:o:');
our ($opt_i, $opt_l, $opt_t);

sub HELP_MESSAGE { print qq{

This script uses data from the TLL to figure out the headwords of the
pages in the PDFs

-i PATH The path to the index.json file from the TLL website.

-l PATH Directory in which to put the file tll-pdf-list.txt, which
        contains the PDF filenames, indexed for easier use.

-t PATH The path to the directory containing the TLL PDFs.
    }
}

my ($path, $list, $list_fh);
unless ($opt_t and $opt_l and $opt_i) {
    die "Error. Options -t, -l and -i are all required.\n";
}
my $json_file = $opt_i;
$path = $opt_t;
chdir $path;
$list = $opt_l;

$list = File::Spec->catfile($list, 'tll-pdf-list.txt');
open $list_fh, ">$list" or die "Could not open $list for writing: $!";
print STDERR "Writing file list to $list\n";

my (@files, @sorted);
sub compare {
    ($a =~ /ThLL(?: vol\. |_)(.*?) /)[0] cmp ($b =~ /ThLL(?: vol\. |_)(.*?) /)[0]
        || $a cmp $b;
}

opendir(my $dh, $path);
while(readdir $dh) {
    next if m/^\./;
    next unless m/\.pdf$/i;
    next unless m/ThLL/;
    next if m/ThLL_IX_1__3_/; # No bookmark info available yet 
    push @files, $_;
}
closedir $dh;
@sorted = sort compare @files;

my @fascicles;
my $index = 0;
my %bookmarks;
foreach my $file (@sorted) {
    print STDERR "Processing $file\n";
    $index ++;
    print $list_fh "$index\t$file\n" if $opt_t;
    my ($vol, $cs, $ce) = get_vol_and_col($file);
    print "$vol, $cs, $ce\n";
    push @fascicles, [$vol, $cs, $ce, $index];
}

# exit;

# Index for TLL pageview on website; hopeless to parse as JSON 
open(my $json_fh, "<:encoding(UTF-8)", $json_file)
    or die("Can't open $json_file: $!\n");
my $junk = <$json_fh>; # throw away first line
while (<$json_fh>) {
    m#\{"0":\{"_":"(.*?)\s+<a onclick=\\"rI\(event,'-/(.*?)\.(jpg|pdf)#;
    my $word = $1;
    my $vol_col = $2;
    warn "BAD: $_" unless $word and $vol_col;
    $word =~ s#</?small>##g;
    $word =~ s#^\d\.##g;
    $word =~ s#<x->.*$##g;
    $word =~ s#,.*$##g;
    $word =~ s#[()?]##g;
    $vol_col =~ m/(.*)\.(\d+)$/;
    my $vol = $1;
    my $col = $2;
    $vol =~ s/,/./g;
    $index = 0;
    my $start_col;
    foreach my $fasc (@fascicles) {
        print "$vol, $col, @{$fasc}\n";
        if ($vol eq @{$fasc}[0] and $col >= @{$fasc}[1] and $col <= @{$fasc}[2]) {
            print STDERR ">>@{$fasc}\n";
            $index = @{$fasc}[3];
            $start_col = @{$fasc}[1];
            last;
        }
    }
    if ($index) {
        my $page = (($col - $start_col) / 2) + 1;
        $bookmarks{$word} = "$index\t$page";
        print "$word -> $vol -> $col -> $index -> $page\n";
    }
    else {
        print STDERR "Error processing $word\n";
    }

}

exit;


close $list_fh;

foreach my $k (sort keys %bookmarks) {
    print $k."\t".$bookmarks{$k}."\n";
}

sub get_vol_and_col {
    my $filename = shift;
    if ($filename =~ m/ThLL_IX_1__3_/) {
        return ["9.1.3", "503", "530"];
    }
    # Volume number is either one set of digits or two.  We don't care about the third part of the volume number, since the json index does not use it and in any case it is not used consistently in filenames to denote the fascicle.  
    die $! unless $filename =~ m/ThLL vol\. ((?:onom|\d+)(?:\.\d+)?)/;
    my $vol = $1;
    $vol =~ s/onom/o/;
    $vol =~ s/^0//; # Leading zero used inconsistently
    die $! unless
        $filename =~ m/ThLL vol\. (?:onom|\d+)(?:[\.\d]+)* col\. (\d+)–(\d+)/; # en dash!
    my $col_start = $1;
    my $col_end = $2;
    return $vol, $col_start, $col_end;
}
