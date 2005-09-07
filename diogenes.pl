#!/usr/bin/perl -w

# This script can be linked to in order to run the Diogenes
# command-line interface from a directory other than its own.  E.g.:
# ln -s diogenes.pl /usr/local/bin/diogenes

use strict;
use File::Basename;
my $path = $0;
my $level = 0;
while (-l $path)
{
    $path = readlink $path;
    die "Error following symlink: $!" unless defined $path;
    die "Circular link!" if $level > 20;
}
my $dir = dirname($path);

chdir $dir;

exec "perl", "./diogenes", @ARGV;

