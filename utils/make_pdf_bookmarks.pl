#!/usr/bin/perl -w
use strict;
use warnings;
use 5.012;
use autodie;
use File::Spec::Functions qw(:ALL);
use Getopt::Std;
getopts ('t:l:o:');
our ($opt_t, $opt_l, $opt_o);

sub HELP_MESSAGE { print qq{

This script parses the bookmarks of a PDF of a lexicon, extracting the
page numbers for use in jumping to the correct page when looking up a
word in Diogenes.  It was designed for the TLL, but also works on
others, such as the OLD.

-t PATH The path to the directory containing the PDFs of the TLL,
        which are expected to have their original names, as downloaded
        from the TLL website.  Requires a value for the -l switch

-l PATH Directory in which to put the file tll-pdf-list.txt, which
        contains the PDF filenames, indexed for easier use.

-o PATH Full path to the single PDF file containing the OLD.
    }
}

my ($path, $list, $list_fh);
if ($opt_t) {
    die "Error. Option -t requires option -l.\n" unless $opt_l;
    $path = $opt_t;
    chdir $path;
    $list = $opt_l;

    $list = File::Spec->catfile($list, 'tll-pdf-list.txt');
    open $list_fh, ">$list" or die "Could not open $list for writing: $!";
    print STDERR "Writing file list to $list\n";

}
elsif ($opt_o) {
    $path = $opt_o;
}
else {
    die ("Error.  Supply a value for either -t or -o.\n");
}


my (@files, @sorted);
sub compare {
    ($a =~ /ThLL vol\. (.*?) \(/)[0] cmp ($b =~ /ThLL vol\. (.*?) \(/)[0]
        || $a cmp $b;
}

if ($opt_t) {
    opendir(my $dh, $path);
    while(readdir $dh) {
        next if m/^\./;
        next unless m/\.pdf$/i;
        next unless m/ThLL/;
        push @files, $_;
    }
    closedir $dh;

    @sorted = sort compare @files;
}
else {
    push @sorted, $path;
}

my $index = 0;
my %bookmarks;
foreach my $file (@sorted) {
    print STDERR "Processing $file\n";
    $index ++;
    print $list_fh "$index\t$file\n" if $opt_t;

    # TLL PDF files are encrypted with a blank password, which has to be removed in order for pdftk to work.
    system qq{qpdf '$file' tmp.pdf --decrypt --password=''};

    my @dump = `pdftk tmp.pdf dump_data output - `;
    unlink 'tmp.pdf';

  LINE: while (@dump) {
      my $line = shift @dump;
      next LINE unless $line =~ m/^Bookmark/;
      if ($line =~ m/BookmarkBegin/) {
          my $title = shift @dump;
          my $level = shift @dump;
          my $page = shift @dump;
          die "Parse error: $line; $title; $level; $page\n" unless
              $title =~ s/^BookmarkTitle:\s+(.*)\s*$/$1/;
          die "Parse error: $line; $title; $level; $page\n" unless
              $level =~ s/^BookmarkLevel:\s+(\d+)\s*/$1/;
          die "Parse error: $line; $title; $level; $page\n" unless
              $page  =~ s/^BookmarkPageNumber:\s+(\d+)\s*/$1/;

          if ($opt_o) {
              next LINE if $page <= 20;
              $title =~ s/tif$//;
              $title =~ s/^\d*\s*//;
              $title =~ s/\.$//;
              $title =~ s/[()-]//g;
              $title =~ tr /A-Z/a-z/;


              print "$title\t$page\n";
              next LINE;
          }

          # We only record first entry when a lemma has several
          next LINE if $title =~ m/^[23456789]\.\ /;
          # Addenda.  In vol. 44, these are corrigenda, so we do not
          # want to overwrite the earlier, correct bookmark.
          next LINE if $title =~ m/\[ADD\]/;
          # Leading 1.
          $title =~ s/^1\.\s+//;
          # Embedded punctuation
          $title =~ s/\&lt;//g;
          $title =~ s/\&gt;//g;
          $title =~ s/\.\.\.//g;
          $title =~ s/[()!?.]//g;
          # Odd fragments
          next LINE if $title =~ m/^[ ,\-]/;

          # Iterate over comma-separated forms
        WORD: while ($title =~ m/(\w+?)(?:,\s+|\s*$)/g) {
            my $word = $1;
            next WORD if $word =~ m/-/;
            next WORD if $word =~ m/^(us|onis)$/;

            $bookmarks{$word} = "$index\t$page";
        }


      }
      else {
          die "Parse error (2): $line\n";
      }
  }
}

if ($opt_t) {
    close $list_fh;

    foreach my $k (sort keys %bookmarks) {
        print $k."\t".$bookmarks{$k}."\n";
    }
}
