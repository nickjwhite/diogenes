#!/usr/bin/perl -w
# Starts a daemon running in the background and listening at a 
# specified port, whose only purpose is to invoke the Diogenes.cgi 
# script for a web browser on the same machine. 
# It caches the CGI script for speed, so restart the daemon if you edit
# the CGI script.
#
# Needs LWP-5.32 or better.
#
# Todo: make this a proper, multiply preforking server with locking on
# the parent socket

BEGIN 
{
	print "\nStarting Diogenes. Please wait ...\n";
}

package Diogenes_Daemon;
require 5.005;
use strict;
use vars qw($client $params $flag $OS $config);
$|=1;

# Script to pre-compile and run
my $CGI_SCRIPT = 'Diogenes.cgi';
# A pre-forked process?  Set this to 0 if you don't want an extra
# process hanging around (unix only -- Windows must pre-fork at least
# one).  
my $PRE_FORK = 1;


use FindBin;
use lib "$FindBin::Bin";   
use HTTP::Daemon;  
use CGI qw(-nodebug -compile :standard);
use CGI::Carp 'fatalsToBrowser';
use HTTP::Request;
use HTTP::Status;
use HTTP::Headers;
use Cwd;
use Diogenes 0.9;
use Net::Domain qw(hostfqdn);
use Socket;
use Getopt::Std;
use vars qw/$opt_d $opt_p $opt_h $opt_H $opt_l $opt_m/;

unless (getopts('dp:hH:lm:'))
{
    print <<"END";

USAGE: Daemon.pl [-dhl] [-p port] [-H host] [-m netmask]

-h  Use current network hostname, so that Diogenes can be accessed by
    other computers on the network (localhost is the default).

-H  Specify a hostname to bind to.

-p  Specify a port to bind to (8888 is the default).

-l  Check to make sure that all queries are from localhost.

-m  Specify the netmask (eg. 255.255.0.0); external queries will be 
    refused.  

-d  Turn on debugging output.

END
    exit;
}

# Port to listen at:
my $PORT = '8888';
$PORT = $opt_p if defined $opt_p;
if ($PORT =~ /\D/ or $PORT < 1024)
{
        print "\nInvalid port number!\nPress Enter to end.\n";
        <>;
        exit;
}

# Hostname
my $HOST = 'localhost';
$HOST = hostfqdn() if defined $opt_h;
$HOST = $opt_H if defined $opt_H;
#my $HOST_num = gethostbyname $HOST or die "Can't resolve $HOST: $!\n;
#$HOST_num = join ".", unpack('C4', $HOST_num);
my $HOST_dot = inet_ntoa(inet_aton($HOST));
my $HOST_long = unpack ('N', inet_aton($HOST));

# Netmask
my $netmask = 0;
$netmask = unpack ('N', inet_aton($opt_m)) if defined $opt_m;

my $cgi_subroutine;
my $DEBUG = 0;
$DEBUG = 1 if $opt_d;
$| = 1;

# Check the setup
my $init = new Diogenes(-type => 'none');
if ($init->{cgi_root_dir})
{
        if (-d $init->{cgi_root_dir})
        {
                chdir $init->{cgi_root_dir} ;
                print "Changing to $init->{cgi_root_dir}\n" if $DEBUG;
        }
        else
        {
                die "Server root directory $init->{cgi_root_dir} does not exist\n.";
        }
}
my $root_dir = cwd;
my $temp_params = "$root_dir/params.tmp";
print "Server Root: $root_dir\n" if $DEBUG;
find_os();

for my $dir ("$init->{cgi_tmp_dir}", "$init->{cgi_img_dir_absolute}", 
                         "$root_dir$init->{cgi_img_dir_relative}")
{
        unless (-d $dir)
        {
                print STDERR "\nConfiguration Error: directory $dir ",
                        "does not exist\n"; 
                print "Press Enter to exit.";
                <>;
                exit;
        }
}

# See if an instance of the daemon is already running
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->agent('Diogenes_probe');
my $test_request = HTTP::Request->new(GET => 'http://'.$HOST.':'.$PORT);
my $test_response = $ua->request($test_request);

if (not $test_response->is_error)
{
        print "There's already a server listening at port $PORT of $HOST.\n";   
        print "Unable to start the Diogenes Daemon.\n"; 
        print "Press Enter to exit.\n"; 
        <>;
        exit;
}

make_cgi_subroutine();

my $server = HTTP::Daemon->new(
                                                                LocalAddr => $HOST,
                                                                Reuse => 1,
                                                                LocalPort => $PORT
                                                                ) or do {
                                        print "Unable to bind to port $PORT of $HOST: $!\n";
                                                                            print "Press Enter to end.";
                                                                            <>;
                                                                            exit;
                                        };

# To let the CGI program know it's us that invoked it.
$flag = 1; 

print "\nStartup complete. ", 
          "You may now point your browser at ",
          "this address:\n",
          $server->url, "\n",
          "\n(Press control-c to quit.)\n\n";

warn "Local address: $HOST_dot\n" if $DEBUG;


# Wait loop for requests.  Global var $client is not only an object ref, but
# also the filehandle ref we write back to.

# The fork() emulation in Perl under MS Windows is broken, and
# segfaults frequently with a normally forking server.  So instead, we
# prefork one (and only one) child right away to handle connections.
# A similar preforking server for unix can reclaim memory, too. 
# Should this should be generalized to allow forking more children?

my $pid;

if ($OS eq 'MS')
{
        $pid = fork;
        if ($pid)
        {       # I am the parent -- I do nothing but wait for my child to exit.
                openBrowser();#open the default browser to the designated address
                wait;
        }
        elsif (not defined $pid)
        {
                # Fork failed.
                print STDERR "Unable to fork!\n";
        }
        else
        {       # I am the child -- I wait for a request and process it.
                while ($client = $server->accept)
                {
                        # Windows gets confused if we die in midstream w/o chdir'ing # back
                        chdir $root_dir or die "Couldn't chdir to $root_dir: $!\n";
                        handle_request();
                }
        }
}
elsif ($PRE_FORK)
{
        {
                $pid = fork;
                if ($pid)
                {       # I am the parent -- I do nothing but wait for my child to exit.
                        wait;
                }
                elsif (not defined $pid)
                {
                        # Fork failed.
                        print STDERR "Unable to fork!\n";
                }
                else
                {       # I am the child -- I wait for a request and process it.
                        while ($client = $server->accept)
                        {
                                # Windows gets confused if we die in midstream w/o chdir'ing # back
                                chdir $root_dir or die "Couldn't chdir to $root_dir: $!\n";
                                handle_request();
                                exit 0;  # Reclaim memory
                        }
        
                }
        }
        continue { redo }; 
}
else 
{
        # A "normal" forking server
#       $SIG{CHLD} = 'IGNORE';
        while ($client = $server->accept) 
        {
                handle_connection();
                close $client;
        }
}

print "An error has occurred in receiving your web browser's connection.\n";
print "Press Enter to end.";
<>;
exit;

# Process each request by forking a child (non-preforking, unix only).
sub handle_connection
{
        $pid = fork;
        if ($pid)
        {       # I am the parent -- I do nothing.
                close $client;
                return;
        }
        elsif (not defined $pid)
        {
                # Fork failed.
                print STDERR "Unable to fork!\n";
        }
        else
        {       # I am the child -- I process the request.
                handle_request();
                exit 0; # Kill children off to reclaim their memory
        }
}

sub handle_request
{
        my $remote_host = $client->peerhost;
    warn "Request from: ".$remote_host."\n" if $DEBUG;
    
    my $request = $client->get_request;
        unless (defined $request)
        {
                warn "Bad request\n" ;
                return;
        }
REQUEST:
        {
                warn "Requested URL: ".$request->url->as_string."\n" if $DEBUG;
                                
                if (not defined $remote_host 
          or ($opt_l and $remote_host ne $HOST_dot )
          or ($netmask and (unpack ('N', inet_aton($remote_host)) & $netmask) != 
                            ($HOST_long & $netmask) ))
                {
                        warn  "WARNING! WARNING! ... \n" .
                  "Connection attempted from an unauthorized " .
                              "computer: $remote_host\n";
                        $client->send_error(RC_FORBIDDEN);
                        last REQUEST
                }

                
                # We only deal with GET and POST methods
                unless ($request->method eq 'GET' or $request->method eq 'POST')
                {
                        warn "Illegal method: only GET and POST are supported: ".$request->method."\n";  
                        $client->send_error(RC_NOT_IMPLEMENTED);
                        last REQUEST
                }
                my $requested_file = ($request->url->path);
                warn "Requested file: $requested_file; cwd: ".cwd."\n" if $DEBUG;
                $requested_file = $CGI_SCRIPT if $requested_file eq '/';
                # Internet exploder stupidity
                $requested_file =~ s#^\Q$root_dir\E##;  
                $requested_file =~ s#^[/\\]##;
                $requested_file = $CGI_SCRIPT if $requested_file =~ m/daemon/i;
                $requested_file = $CGI_SCRIPT if $requested_file =~ m/Diogenes\.cgi/i;
                warn "Relative file name: $requested_file\n" if $DEBUG;
                $params = '';
                
                # Deal with the various ways our CGI script might be
                # requested by a browser. We only serve one script here.
                if ($requested_file =~ m/\.cgi/i or $requested_file eq $CGI_SCRIPT)
                {
                        if ($request -> method eq 'GET')
                        {
                                $params = $request->url->query_form;        
                                $params ||= '';
                                warn "GET request.".($params ? " Query:$params\n" : "\n") if $DEBUG;
                        }
                        else ## eq 'POST'
                        { 
                                if ($request->headers->content_type eq 'application/x-www-form-urlencoded')
                                {
                                        $params = $request->content;
                                        $params ||= '';
                                        warn "POST request. Content: $params\n" if $DEBUG;
                                }
                                elsif ($request->headers->content_type =~ /multipart.*/)
                                {
                                        warn "Multipart form submission is not ",
                                        "supported by the Diogenes Daemon.\n";
                                        $client->send_error(RC_NOT_IMPLEMENTED);
                                        last REQUEST
                                }
                        }
                        
                        # Execute the pre-compiled CGI script
                        $client->send_basic_header(RC_OK, '(OK)', 'HTTP/1.1');

                        if ($requested_file eq $CGI_SCRIPT)
                        {
                                # Trap those exceptions
                                eval {$cgi_subroutine->()};
                                warn "Diogenes Error: $@" if $@; 
                        }
                        else
                        {
                                # Other cgi scripts just get executed
                                open PARAMS, ">$temp_params" or die "Can't open $temp_params: $!";
                                print PARAMS $params;
                                close PARAMS or die "Can't close $temp_params: $!";
                                warn "Executing file $requested_file in $root_dir\n" if $DEBUG;
                                # Specify Perl, since Win32 doesn't grok the shebang
                                my $out;
                                if ($OS eq 'MS' and     -e 'c:\\perl\\bin\\perl')
                                {       # Some installs don't set the PATH
                                        $out = `c:\\perl\\bin\\perl $requested_file $temp_params`;
                                }
                                else
                                {       
                                        $out = `perl $requested_file $temp_params`;
                                }
                                unlink $temp_params;
                                my $resp = HTTP::Response->new(RC_OK);
                                $resp->push_header('charset' => 'iso-8859-1');
                                $resp->push_header('Content_Type' => 'text/html');
                                $resp->content($out);
                                $client->send_response($resp);
                        }
                        
                }
                else
                {
                        # Merrily serve up all non .cgi files (but only files in the
                        # current working directory).
                        $requested_file =~ s#^/##;
                        warn "Sending file: $requested_file\n" if $DEBUG;
                        #Windows IE doesn't like this:
                        #my $ret = $client->send_file_response($root_dir.$requested_file);
                        my $ret = $client->send_file_response($requested_file);
                        warn "File $requested_file not found!\n" unless $ret eq RC_OK;
                }
        }
    close $client;
    undef $client;
}

sub make_cgi_subroutine
{
        my $cgi_script;
        open SCRIPT, "<$CGI_SCRIPT" or warn "Unable to find the file $CGI_SCRIPT.\n", 
                 "The current configuration says it should be located in $root_dir.\n";
        binmode SCRIPT;
        {
                local $/; undef $/;
                ($cgi_script) = <SCRIPT>;
        }
        my $code = << 'CODE_END';

$cgi_subroutine = sub
{
        package Diogenes_Daemon;
        open *Diogenes_Daemon::client;
        select $Diogenes_Daemon::client;
        $| = 1;
        
CODE_END

        $code .= $cgi_script . '}';
        
        # $code now has the code of the CGI script wrapped in a
        # subroutine declaration, which we can call later.
        eval $code;
        if ($@)
        {
                print "Error compiling CGI script: $@\n";
                print "Press Enter to exit.";
                <>;
                exit;
        }
}

sub find_os
{
        unless ($OS) 
        {
        unless ($OS = $^O) 
                {
                require Config;
                $OS = $Config::Config{'osname'};
        }       
        }
        if ($OS=~/MSWin/i or $OS =~/dos/) 
        {
                $OS = 'MS';
                $config = $root_dir.'\\diogenes.ini';
                unless (-e $config)
                {
                        print "Configuration file diogenes.ini not found in the " .
                        "current folder ($root_dir).  Run Setup to generate one.\n"; 
                        print "\n\nPress Enter to exit.";
                        <>;
                        exit;
                }
        } 
        else 
        {
        $OS = 'UNIX';
                undef $config;
        }                        
}

sub openBrowser
{
        # I guess this works for some Windows folk, but it seems pretty
        # timing dependent to me:
        #system("start http://localhost:$PORT");
        #system("start iexplore.exe http://localhost:$PORT");
}
