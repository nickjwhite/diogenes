#!/usr/bin/perl -w

my $data_dir = "/home/pj/Classics-Data";
my $tlg_dir = "$data_dir/tlg_e";

my @words = split /[\x80-\xff]/, `cat $tlg_dir/tlgwlist.inx`;

open OUT, ">tlg.words" or die $!;

for (@words) {
    tr[A-Z][a-z];
    next if m#^iaewbafrenemoun#;
    next if m#\!#;
    print OUT "$_\n";
    # And try uppercase, too.
    print OUT "*$_\n";
    print OUT "*$_\n" if s/^([aeiouhw])([\\\/=|()]+)/$2$1/;
    print OUT "*$_\n" if s/^([aeiouhw][aeiouhw])([\\\/=|()]+)/$2$1/;
}

close OUT or die $!;
1;
