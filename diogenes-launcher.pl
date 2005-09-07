#!/usr/bin/perl -w

# This is a user-friendly start-up script for Diogenes.  It makes sure
# at least one database can be found, then is starts Daemon.pl, then
# launches a browser.

use strict;
require 5.005;
use Diogenes;
use Cwd;
my $cwd = cwd;
my $debug = 1;

my $flag_file = ".diogenes.flag";
unlink $flag_file if -e $flag_file;

my $init = new Diogenes(-type => 'none');

# Make sure we can find a database.
my %databases = $init->check_db_all();
# print Dumper (%databases);

# Only bother to check CD-Rom drives at this early point if there is
# no other accessible database.  All we need to know is that there is
# one accessible database.
if (keys %databases == 0)
{
    %databases = $init->check_cdroms;
}
# print Dumper (%databases);


# Trigger error page in browser unless at least one viable database
# has been found.
if (keys %databases == 0)
{
    $ENV{diogenes_no_databases} = 1;
}

my $daemon_pid = fork;

die "Unable to fork Daemon" unless defined $daemon_pid;
if ($daemon_pid == 0)
{
    exec("perl", "./Daemon.pl") or die "Can't exec Daemon!";
}
print "Daemon pid: $daemon_pid\n" if $debug;

my $url;
while (1)
{
    sleep 1; 
    if (-e $flag_file)
    {
        open FLAG, "<./$flag_file" or die "Could not open flag: $!";
        $url = <FLAG>;
        close FLAG;
        last;
    }
}

my $browser_pid;

 if ($Diogenes::OS eq 'windows')
 {
#      system("windows-browser $url");
        system("../Diogenes-browser/Diogenes-browser.exe");
 }
 else
{
    $browser_pid = fork;

    die "Unable to fork browser" unless defined $browser_pid;
    if ($browser_pid == 0)
    {
        exec_browser();
    }
    print "Browser pid: $browser_pid\n" if $debug;
}

# On Windows, when the parent exits, the children automatically exit,
# too.  So all we need to do is to launch the browser with system and
# exit when it returns.

my $swan_song = sub {
    kill 1, $daemon_pid;
    kill 9, $browser_pid if $browser_pid;
};

if ($Diogenes::OS eq 'windows')
{
    exit;
}
else
{

    $SIG{HUP}  = $swan_song;
    $SIG{INT}  = $swan_song;
    $SIG{KILL} = $swan_song;

    my $pid = wait;

    if ($pid == $daemon_pid)
    {
        kill 9, $browser_pid;
    }
    elsif ($pid == $browser_pid)
    {
        kill 1, $daemon_pid;
    }
    else
    {
        warn "Strange child $pid reaped\n";
    }
}

sub exec_browser
{
    if ($Diogenes::OS eq 'mac')
    {
        exec ("../Diogenes-browser.app/Contents/MacOS/Diogenes-browser");
    }
#     elsif ($Diogenes::OS eq 'windows')
#     {
#         exec ("../Diogenes-browser/Diogenes-browser.exe");
#     }
    else
    {
        exec ("diogenes-browser", $url)
            or
            exec ("konqueror", $url)
            or
            exec ("mozilla", $url)
            or
            die "Can't exec browser!";
    }
}


    # In the windows zip file there should only be the .bat file and
    # various subdirs

    # I guess this works for some Windows folk, but it seems pretty
    # timing dependent to me:
    #system("start http://localhost:$PORT");
    #system("start iexplore.exe http://localhost:$PORT");
