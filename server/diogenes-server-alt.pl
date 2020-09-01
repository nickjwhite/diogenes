#!/usr/bin/env perl

# An effort to put together a more robust server using Net::Server.
# Unfortunately, it does not work very well on Windows.  Requires
# various changes to work:






use strict;
use warnings;
use FindBin qw($Bin);
use File::Spec::Functions qw(:ALL);
push @INC, '.';
# Use local CPAN
use lib ($Bin, catdir($Bin, '..', 'dependencies', 'CPAN') );

my $home = $ENV{'HOME'};
package Diogenes::Server;
use base qw(Net::Server::HTTP);

my $debug = 1;
use Diogenes::Base;
use vars qw($flag);

my %tll_list;
my %mime_type = (
    'txt'   => 'text/plain',
    'html'  => 'text/html',
    'js'    => 'text/javascript',
    'css'   => 'text/css',
    'jpg'   => 'image/jpeg',
    'png'   => 'image/png',
    'gif'   => 'image/gif',
    'ico'   => 'image/x-icon',
    'pdf'   => 'application/pdf',
    'woff'  => 'font/woff',
    );

use HTTP::Date qw(time2str);
# Eventually upgrade to IO::Socket::IP when it is part of the core
use IO::Socket::INET;

my $config_dir = $Diogenes::Base::config_dir;
unlink $config_dir if (-e $config_dir and not -d $config_dir);
mkdir $config_dir unless (-e $config_dir and -d $config_dir);
my $lock_file = File::Spec->catfile($config_dir, 'diogenes-lock.json');
my $lock_file_temp = File::Spec->catfile($config_dir, 'diogenes-lock-temp.json');
$ENV{Diogenes_Debug} = 1 if $debug;
# To let the CGI program know it is us that invoked it.
$flag = 1;

# Find an open port, starting here.
my $try_port = '8888';
my $max_port_tries = 20;
my $port_tries = 0;
my $port;
while ($port_tries < $max_port_tries) {
    my $socket = IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => $try_port);
    if ($socket) {
        print "Port $try_port in use.\n";
        $socket->close;
        $port_tries++;
        $try_port++;
    }
    else {
        $port = $try_port;
        last;
    }
}
die "Error: Unable to bind to a port after $port_tries attempts.\n" unless $port;

my $server = new Diogenes::Server(
    port  => $port,
    host => 'localhost',
    ipv   => '*', # IPv6 if available
    max_header_size => 128*1024*1024
    );
$server->run;

sub pre_loop_hook {
    print "\nStartup complete. ",
        "You may now point your browser at ",
        "this address:\n",
        "http://localhost:$port\n";
    write_lock($port)
}

sub default_server_type { 'PreFork' }

sub process_http_request {
    my $self = shift;
    # Env seems to be cleared out by Net::Server.
    $ENV{'HOME'} = $home;
    
    my $splash = 'Diogenes.cgi';
    my $path = $ENV{'PATH_INFO'};
    $path =~ s#^[/\\]##;
    $path = $splash unless $path;
    print STDERR "Path: $path\n" if $debug;

    if ($path =~ m/\.cgi$/i) {
        $path = File::Spec->catfile($FindBin::Bin, $path);
        print STDERR "Serving CGI script: $path\n" if $debug;
        print STDERR "Query string: " . $ENV{QUERY_STRING} . "\n" if
            $ENV{QUERY_STRING} and $debug;
        # Silence CGI.pm warnings
        $ENV{"QUERY_STRING"} = '' unless $ENV{"QUERY_STRING"};
        print "Content-Type: text/html; charset=UTF-8\n";
        print "Server: Diogenes\n";
        print "Date: " . time2str(time) . "\n";
        print "\n";

        # This mechanism, which uses IPC::Open3, causes serious
        # blocking problems with Perseus.cgi, leading to incomplete
        # output.
        # return $self->exec_cgi($path);
        # So instead, we just eval the script
        do $path;
        warn "Diogenes eval Error: $@" if $@;
        # If we do not exit here, cgi state can get mixed up after an
        # error.
        # return;
        exit;
        
    }
    elsif ($path =~ m#^tll-pdf|ox-lat-dict\.pdf#) {
        # Serve TLL/OLD pdfs, but first translate filename
        my %args_init = (-type => 'none');
        my $init = new Diogenes::Base(%args_init);
        my ($pdf_path, $pdf_file);
        
        if ($path =~ m#^tll-pdf#) {
            $path =~ m#^tll-pdf/(\d+).pdf#;
            my $file_number = $1;
            warn "Bad PDF file URI" unless $file_number;
            
            tll_list_read() unless %tll_list;
            $pdf_file = $tll_list{$file_number};
            warn "Bad PDF file number" unless $pdf_file;
            warn "Translating PDF file $file_number as $pdf_file\n" if $debug;
            
            # $pdf_file = uri_escape($pdf_file);
            $pdf_path = $init->{tll_pdf_dir};
            $pdf_file = File::Spec->catfile($pdf_path, $pdf_file);
        }
        else {
            $pdf_path = $init->{old_pdf_dir};
            $pdf_file = $init->{old_pdf_dir};
        }
        
        unless ($pdf_path) {
            warn "Error: pdf_path not set\n";
            $self->send_status(404, "Location of the requested pdf file has not been set.");
            return;
        }
        unless (-e $pdf_path) {
            warn "Error: pdf_path ($pdf_path) does not exist.\n";
            $self->send_status(404, "The requested pdf file ($pdf_path) was not found.");
            return;
        }
        warn "Serving PDF file $pdf_file\n" if $debug;
        unless (-e $pdf_file) {
            warn "Error: pdf_file ($pdf_file) does not exist\n";
            $self->send_status(404, "Requested pdf file ($pdf_file) was not found.");
            return;
        }
        
        $self->send_file($pdf_file);
    }
    else  {
        $path = File::Spec->catfile($FindBin::Bin, $path);
        $self->send_file($path);
    }
}

sub send_file {
    my ($self, $file) = @_;
    print STDERR "Serving file: $file\n" if $debug;
    
    sysopen(my $fh, $file, 0) or
            return $self->send_status(403, "Could not open file: $file.");

    my($size, $mtime) = (stat $fh)[7, 9];
    my $type = $1 if $file =~ m/\.([^.]*?)$/i;
    my $mime = $mime_type{$type};
    print "Server: Diogenes\n";
    print "Date: " . time2str(time) . "\n";
    print "Content-Type: $mime; charset=UTF-8\n" if $mime;
    print "Content-Length: $size\n" if $size;
    print "Last-Modified: " . time2str($mtime) . "\n" if $mtime;
    print "\n";

    my $cnt = 0;
    my $buf = "";
    my $n;
    while ($n = sysread($fh, $buf, 8*1024)) {
        last if !$n;
        $cnt += $n;
        print $buf;
    }
    close($fh);
    print STDERR "Warning: count $cnt does not equal $size\n" unless $cnt == $size;
}

sub write_lock
{
    # Write number of port to lock file to indicate that we are ready
    # to receive connections.
    my $port = shift;
    unlink $lock_file;
    unlink $lock_file_temp;
    print "Writing $lock_file\n" if $debug;
    open FLAG, ">$lock_file_temp" or warn "Could not create lock file: $!";
    print FLAG
"{
\"port\": $port,
\"pid\": $$
}";
    # Flush filehandle
    close FLAG;
    # This ought to address the race condition whereby the browser process can read the file after it has been created but before it has been written to.  The linking action within the rename ought to be atomic.
    rename $lock_file_temp, $lock_file;
}


sub tll_list_read {
    my $data_dir = File::Spec->catdir($FindBin::Bin, '..', 'dependencies', 'data');
    my $list = File::Spec->catfile($data_dir, 'tll-pdf-list.txt');
    
    open my $list_fh, '<:encoding(UTF-8)', $list or
        die "Could not open $list: $!";
    while (<$list_fh>) {
        m/^(\d+)\t(.*)$/ or die "Malformed list entry: $_";
        $tll_list{$1} = $2;
    }
}
