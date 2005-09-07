#!/usr/bin/perl -w

# This script can be linked to in order to run the Diogenes
# web-interface from a directory other than its own.  E.g.: ln -s
# diogenes-web.sh /usr/local/bin/diogenes-web

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

exec "perl", "./diogenes-launcher.pl", @ARGV;

