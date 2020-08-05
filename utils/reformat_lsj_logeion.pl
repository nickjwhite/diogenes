# Lightly reformat the Logeion LSJ.  Cut frontmatter, etc. from each file and remove spurious newlines within entries.

#!/usr/bin/env -S perl -w
use strict;
use warnings;
# utf8 in and out.
binmode STDOUT, ':utf8';
binmode STDIN, ':utf8';
use open ':utf8';
my $in_entry = 0;

while (<>) {
    $in_entry = 1 if m#^\s*<div2\s#;
    chomp unless m#</div2>\s*$#;
    print $_ if $in_entry;
    $in_entry = 0 if m#</div2>\s*$#;
}
