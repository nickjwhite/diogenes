#!/usr/bin/perl -w

# Starts a daemon running in the background and listening at a 
# specified port, whose only purpose is to invoke the Diogenes.cgi 
# script for a web browser on the same machine. 
# It caches the CGI script for speed, so restart the daemon if you edit
# the CGI script.
#
# Needs LWP-5.32 or better.
#
# Possible Todos:
#
# Handle decoding of multipart forms (which might then need to be
# re-encoded as URL-escaped query strings).

BEGIN 
{
    print "\nStarting Diogenes...\n";
}


package Diogenes_Daemon;
require 5.005;
use strict;
use vars qw($client $params $flag $config);
$|=1;

# Script to pre-compile and run
my $CGI_SCRIPT = 'Diogenes.cgi';

# A pre-forked process?  If set to 1 on unix, this will leave an extra
# process hanging around after the parent has been killed.
my $PRE_FORK = 0;

use FindBin qw($Bin);
use File::Spec::Functions qw(:ALL);
use lib ($Bin, catdir($Bin,'CPAN') );

use HTTP::Daemon;  
use CGI qw(-nodebug -compile :standard);
use CGI::Carp 'fatalsToBrowser';
# From v. 3.10 XHTML defaults to 1, which turns on multipart forms,
# which we can't handle.
$CGI::XHTML =0;

use HTTP::Request;
use HTTP::Status;
use HTTP::Headers;
use Cwd;
use Diogenes::Base;
use Net::Domain qw(hostfqdn);
use Socket;
use Getopt::Std;
use vars qw/$opt_d $opt_p $opt_h $opt_H $opt_l $opt_m $opt_D $opt_b/;

my $config_dir = $Diogenes::Base::config_dir_base;
unlink $config_dir if (-e $config_dir and not -d $config_dir);
mkdir $config_dir unless (-e $config_dir and -d $config_dir);
my $lock_file = File::Spec->catfile($config_dir, '.diogenes.run');

# Mozilla wants this: it ignores css files of type text/plain.
use LWP::MediaTypes qw(add_type);
add_type('text/css', '.css');

unless (getopts('dDp:hH:lm:b'))
{
    print <<"END";

USAGE: diogenes-server.pl [-dhlb] [-p port] [-H host] [-m netmask]

    -h  Use current network hostname, so that Diogenes can be accessed by
    other computers on the network (localhost is the default).

    -H  Specify a hostname to bind to.

    -p Specify a port to bind to (8888 is the default).  If
       unavailable, will try again by increasing the number.

    -l  Check to make sure that all queries are from localhost.

    -m  Specify the netmask (eg. 255.255.0.0); external queries will be 
    refused.  

    -d  Turn on debugging output.

    -b  Print message about launching a browser instead of the usual message.
END
    exit;
}

my %cgi_subroutine;
my $DEBUG = 0;
$DEBUG = 1 if $opt_d;
$| = 1;

print "\@INC: ", join "\n", @INC, "\n" if $DEBUG;

# To let the CGI program know it is us that invoked it.
$flag = 1; 

# Port to start attempting to listen at:
my $PORT = '8888';
$PORT = $opt_p if defined $opt_p;
if ($PORT =~ /\D/ or $PORT < 1024)
{
    print "\nInvalid port number!\n";
    exit;
}

# Hostname

# my $HOST = 'localhost'; ## Not defined in later Fedora
my $HOST = '127.0.0.1';
$HOST = hostfqdn() if defined $opt_h;
$HOST = $opt_H if defined $opt_H;
#my $HOST_num = gethostbyname $HOST or die "Can't resolve $HOST: $!\n;
#$HOST_num = join ".", unpack('C4', $HOST_num);
my $HOST_dot = inet_ntoa(inet_aton($HOST));
my $HOST_long = unpack ('N', inet_aton($HOST));

# Netmask
my $netmask = 0;
$netmask = unpack ('N', inet_aton($opt_m)) if defined $opt_m;

# CGI dirs
my $root_dir = $Bin;
$root_dir .= '/' unless $root_dir =~ m#[/\\]$#;

# Pre-compile the main cgi script
compile_cgi_subroutine("Diogenes.cgi");


print "Server Root: $root_dir\n" if $DEBUG;

# if (-e $lock_file)
# {
#     print "There's a lock file from a previous server.\n";   
#     print "Running diogenes-server-kill.\n";
#     do $root_dir . 'diogenes-server-kill.pl';
# }

my $server;
my $max_port_tries = 20;
my $port_tries = 0;

while ($port_tries < $max_port_tries)
{
    $server = HTTP::Daemon->new
        (LocalAddr => $HOST,
         Reuse => 1,
         LocalPort => $PORT);
    last if $server;
    $port_tries++;
    $PORT++;
}
unless ($server)
{
    print "Unable to bind to a port after $port_tries attempts, up to $PORT of $HOST: $!\n";
    exit;
}


if ($opt_b or $ENV{Diogenes_Launch_Browser})
{
    print "\nSetup complete ... Launching browser.\n";
}
else
{
    print "\nStartup complete. ", 
    "You may now point your browser at ",
    "this address:\n",
    "http://127.0.0.1:".$PORT."\n";
}

warn "Local address: $HOST_dot\n" if $DEBUG;

# Wait loop for requests.  Global var $client is not only an object ref, but
# also the filehandle ref we write back to.

# The fork() emulation in Perl under MS Windows is broken, and
# segfaults frequently with a normally forking server.  So instead, we
# prefork one (and only one) child right away to handle connections.

# This approach would problematic on unix, because after the parent is
# killed, the pre-forked child does not die, but hangs around,
# listening at the socket for one last connection.  It's not a problem
# on Windows, however, since the "child" is really a thread, and so
# dies when the "parent" is killed.

my $pid;

# This causes the accept loop to abort for some reason
# use POSIX qw(:sys_wait_h);
# sub reaper
# {
#     1 until (-1 == waitpid(-1, WNOHANG));
#     print "handler\n";
# }
#  $SIG{CHLD} = \&reaper;

# Supposed to prevent zombies, but doesn't work on OS X
$SIG{CHLD} = 'IGNORE';

if ($Diogenes::Base::OS eq 'windows' or $PRE_FORK)
{
    $pid = fork;
    if ($pid)
    {   # I am the parent -- I do nothing but wait for my child to exit.
        write_lock();
        wait;
    }
    elsif (not defined $pid)
    {
        # Fork failed.
        print STDERR "Unable to fork!\n";
    }
    else
    {
        # I am the child -- I wait for a request and process it.
        while ($client = $server->accept)
        {
            # Windows gets confused if we die in midstream w/o chdir'ing # back
            chdir $root_dir or die "Couldn't chdir to $root_dir: $!\n";
            handle_request();
        }
    }
}
else 
{
    # A "normal" forking server
    write_lock();
    while ($client = $server->accept) 
    {
        handle_connection();
    }
}

print "An error has occurred in receiving your web browser's connection.\n";
exit;

# Process each request by forking a child (non-preforking, unix only).
sub handle_connection
{
    $pid = fork;
    if ($pid)
    {
        # I am the parent -- I do nothing.
        close $client;
        return;
    }
    elsif (not defined $pid)
    {
        # Fork failed.
        print STDERR "Unable to fork!\n";
    }
    else
    {
        # I am the child -- I process the request.
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
#         warn "Full request from browser: ". $request->as_string if $DEBUG;
        
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
        $requested_file = $CGI_SCRIPT if $requested_file =~ m/diogenes-server/i;
        $requested_file = $CGI_SCRIPT if $requested_file =~ m/Diogenes\.cgi/i;
        warn "Relative file name: $requested_file\n" if $DEBUG;

        my $cookie = $request->header('Cookie');
        $ENV{HTTP_COOKIE} = $cookie if $cookie;
        
        # Deal with the various ways our CGI script might be
        # requested by a browser.

        # $params is a global which is accessed by the CGI script and
        # passed as a parameter to CGI->new in order to instantiate
        # the CGI object.  We could pass this info via environment
        # variables, except that for POST methods, CGI.pm wants to
        # read the query data from STDIN.
        $params = '';
        if ($requested_file =~ m/\.cgi/i or $requested_file eq $CGI_SCRIPT)
        {
            if ($request -> method eq 'GET')
            {
                $params = $request->url->query_form;        
                $params ||= '';
                warn "GET request.".($params ? " Query:$params\n" : "\n") if $DEBUG;
                $ENV{REQUEST_METHOD} = 'GET';
                $ENV{QUERY_STRING} = $params;
            }
            else ## eq 'POST'
            { 
                if ($request->headers->content_type eq 'application/x-www-form-urlencoded')
                {
                    $params = $request->content;
                    $params ||= '';
                    warn "POST request. Content: $params\n" if $DEBUG;
                    # We pass the params via the global $param, since
                    # otherwise, we'd need to stuff the params into
                    # our own STDIN, which would cost a fork,
                    # probably.  Tried pretending this was a GET
                    # request, and passing via %ENV, but that was Bad.
                }
                elsif ($request->headers->content_type =~ /multipart.*/)
                # We do not handle multipart submission, since that
                # would need to be turned into a URL-encoded string to
                # pass as an initializer for CGI.pm.  TODO?
                {
                    warn "Multipart form submission is not supported by the Diogenes server.\n";
                    $client->send_error(RC_NOT_IMPLEMENTED);
                    last REQUEST
                }
            }
            # Workaround for annoying CGI.pm bug/warning
            $ENV{QUERY_STRING} = '' unless $ENV{QUERY_STRING};

            
            # Here we compile if necessary and execute any CGI scripts
            $client->send_basic_header(RC_OK, '(OK)', 'HTTP/1.1');
            # This tells CGI.pm the name of the script, which goes into
            # the action parameter of the form element(s)
            $ENV{SCRIPT_NAME} = $requested_file;
            compile_cgi_subroutine($requested_file)
                unless exists $cgi_subroutine{$requested_file}; 
            # Trap any exceptions
            eval {$cgi_subroutine{$requested_file}->()};
            warn "Diogenes Error: $@" if $@; 
        }
        else
        {
            # Merrily serve up all non .cgi files (but only files in the
            # root dir).
            $requested_file =~ s#^/##;
            $requested_file = $root_dir . $requested_file;
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

sub write_lock
{
    # Write number of port to lock file to indicate that we are ready
    # to receive connections.  Mild race condition here, but I'm not
    # sure if anything can be done about it.
    unlink $lock_file;
    print "Writing $lock_file\n";
    open FLAG, ">$lock_file" or warn "Could not make lock file: $!";
    print FLAG
"port $PORT
pid $$
";
    close FLAG;
}
    
sub compile_cgi_subroutine
{
    my $script_file = shift;
    my $cgi_script;
    open SCRIPT, "<$root_dir$script_file" or warn "Unable to find the file $script_file.\n", 
    "The current configuration says it should be located in $root_dir.\n";
    binmode SCRIPT;
    {
        local $/; undef $/;
        ($cgi_script) = <SCRIPT>;
    }
    my $code = << 'CODE_END';

    $cgi_subroutine{$script_file} = sub
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
        exit;
    }
}

