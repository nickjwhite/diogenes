#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;

my (%index_start, %index_end);
my $current = '';
my $offset = 0;
my $biggest = 0;
my $big_one;
my $index_max;
while (<>){
    die unless m#^([^\t]+)#;
    my $form = $1;
    my $key = substr($1, 0, 3);
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
print Data::Dumper->Dump([\%index_start], ['*index_start']);
print Data::Dumper->Dump([\%index_end], ['*index_end']);
print Data::Dumper->Dump([$index_max], ['*index_max']);
