#!/usr/bin/perl -w
use strict;
use 5.012;
use autodie;
use File::Spec::Functions qw(:ALL);

my $path = $ARGV[0];
die "Error: first arg is path to directory with TLL pdfs" unless $path;
chdir $path;

my $list = $ARGV[1];
die "Error: second arg is path to directory to output file-list " unless $list;
$list = File::Spec->catfile($list, 'tll-pdf-list.txt');
open my $list_fh, ">$list" or die "Could not open $list for writing: $!";
print STDERR "Writing file list to $list\n";

my @files;
opendir(my $dh, $path);
while(readdir $dh) {
    next if m/^\./;
    next unless m/\.pdf$/i;
    next unless m/ThLL/;
    push @files, $_;
}
closedir $dh;

my @sorted = sort compare @files;
sub compare {
    ($a =~ /ThLL vol\. (.*?) \(/)[0] cmp ($b =~ /ThLL vol\. (.*?) \(/)[0]
        || $a cmp $b;
}

my $index = 0;
my %bookmarks;
foreach my $file (@sorted) {
    print STDERR "Processing $file\n";
    $index ++;
    print $list_fh "$index\t$file\n";

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

          # We only record first entry when a lemma has several
          next LINE if $title =~ m/^[23456789]\.\ /;
          # Leading 1.
          $title =~ s/^1\.\s+//;
          # Addenda
          $title =~ s/\s*\[ADD\]//;
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

close $list_fh;

foreach my $k (sort keys %bookmarks) {
    print $k."\t".$bookmarks{$k}."\n";
}
