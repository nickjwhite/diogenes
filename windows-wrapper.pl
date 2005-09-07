#!/usr/bin/perl -w

# We can't just run Daemon.pl directly, because our local copy of Perl
# only has "." in INC, so we have to tell it where to find the
# standard libraries.  This file needs to be in the same directory as
# Daemon.pl -- not sure why.

BEGIN
{
    @INC = (".", "../perl", "../lib/", "../site-lib/");
}

use strict;
chdir "../perl/";  # yes, this bizarre thing is necessary.

$ENV{Diogenes_Launch_Browser} = 1;
do "Daemon.pl" or die $!;
