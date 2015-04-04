#!/usr/bin/perl -w
use strict;
use Data::Dumper;

open INP, "<greek-analyses.txt" or die $1;
open OUT, ">greek-analyses.idt" or die $1;

my (%index_start, %index_end);
my $current = '';
my $offset = 0;
my $biggest = 0;
my $big_one;
my $index_max;
while (<INP>){
    die unless m#^([^\t]+)#;
    my $form = $1; 
    my $key = substr($1, 0, 3);
#     print ">$key<\n";
    if ($key ne $current)
    {
        $index_end{$current} = $offset if $current;
        $index_start{$key} = $offset;
        my $size = $offset - ($index_start{$current} || 0);
        if ($size > $biggest) {
            $biggest = $size;
            $big_one = $current
        }
        $current = $key;
    }
    $offset = $offset + length $_;
}
$index_max = $offset;
print OUT Data::Dumper->Dump([\%index_start], ['*index_start']);
print OUT Data::Dumper->Dump([\%index_end], ['*index_end']);
print OUT Data::Dumper->Dump([$index_max], ['*index_max']);

# print "\n$big_one: $biggest\n";
# print Data::Dumper->Dump([\%glosses], ['*glosses']);

close INP or die $!;
close OUT or die $!;
1;
