# Lightly reformat the Logeion Lewis-Short.  Not sure why this one
# uses <div1> instead of <div2> as for LSJ.


#!/usr/bin/env -S perl -w
use strict;
use warnings;
# utf8 in and out.
binmode STDOUT, ':utf8';
binmode STDIN, ':utf8';
use open ':utf8';
my $in_entry = 0;

while (<>) {
    $in_entry = 1 if m#^\s*<div1\s#;
    chomp unless m#</div1>\s*$#;
    print $_ if $in_entry;
    $in_entry = 0 if m#</div1>\s*$#;
}
