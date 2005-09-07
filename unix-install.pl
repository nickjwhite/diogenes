#!/usr/bin/perl -w

# This script just creates symbolic links to the current directory for
# the commands diogenes and diogenes-web 
use strict;
use Cwd;
use File::Spec;

my $cwd = cwd;

unlink "/usr/local/bin/diogenes";
unlink "/usr/local/bin/diogenes-web";

symlink File::Spec->catfile($cwd, "diogenes.pl"), "/usr/local/bin/diogenes";
symlink File::Spec->catfile($cwd, "diogenes-web.pl"), "/usr/local/bin/diogenes";

