#!/usr/bin/perl -w
use strict;
use 5.012;
use autodie;

my $path = $ARGV[0];
die "Error: must pass path to directory with TLL pdfs" unless $path;
chdir $path;

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

my $file_list = '';
my $index = 0;
my %bookmarks;
foreach my $file (@sorted) {
    print STDERR "Processing $file\n";
    $index ++;
    $file_list .= "$index\t$file\n";

    # TLL PDF files are encrypted with a blank password, which has to be removed in order for pdftk to work.
    system qq{qpdf '$file' tmp.pdf --decrypt --password=''};

    my @dump = `pdftk tmp.pdf dump_data output - `;
    unlink 'tmp.pdf';

    while (@dump) {
        my $line = shift @dump;
        next unless $line =~ m/^Bookmark/;
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

            # We only record first entry
            next if $title =~ m/^[23456789]\.\ /;
            # Odd fragments
            next if $title =~ m/^[ ,\-]/;
            # Leading 1.
            $title =~ s/^1\.\s+//;
            # Addenda
            $title =~ s/\s*\[ADD\]//;
            $title =~ s/\&lt;//g;
            $title =~ s/\&gt;//g;
            $title =~ s/\.\.\.//g;
            $title =~ s/^([^(]*)\)/$1/g; # foo)bar
            $title =~ s/([^)]*)\($/$1/g; # foo(bar
            while ($title =~ m/(\w+?)(?:,\s+|\s*$)/g) {
                mark($1, $index, $page);
            }
        }
        else {
            die "Parse error (2): $line\n";
        }
    }
}

sub mark {
    my ($word, $index, $page) = @_;
    $word =~ s/^\s+//;
    $word =~ s/\s+$//;
    
    if ($word =~ m/^(.*?)\((\w+)\)(.*?)$/) {
        # Add word both with and without letters in parens
        $bookmarks{$1.$2.$3} = "$index\t$page";
        $bookmarks{$1.$3} = "$index\t$page";
    }
    else {
        $bookmarks{$word} = "$index\t$page";
    }
}

#print join "; ", %bookmarks;

foreach my $k (sort keys %bookmarks) {
    print $k."\t".$bookmarks{$k}."\n";
}
