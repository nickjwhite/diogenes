#!/usr/bin/perl -w
use strict;

use Diogenes;
use CGI qw(:standard);
use CGI::Carp 'fatalsToBrowser';
$| = 1;

my $q = $Diogenes_Daemon::params ? new CGI($Diogenes_Daemon::params) : new CGI;
print $q->header(-type=>"text/html; charset=utf-8");

use Data::Dumper;    
use Cwd;
use File::Spec;


my $d = new Diogenes(-type => 'none');

my $cwd = cwd;
my $rcfile = catfile($cwd, 'diogenes.config');

my @fields = qw(context cgi_default_corpus cgi_default_encoding browse_lines 
                cgi_input_format phi_file_prefix tlg_dir phi_dir ddp_dir
				unicode_font browser_multiple perseus_links perseus_server) ;

my %perseus_mirrors = ( 'http://www.perseus.tufts.edu/' => 'Massachusetts',
                        'http://perseus.mpiwg-berlin.mpg.de/' => 'Berlin',
    );

my $begin_comment = "\n######## These lines have been added by the program Settings.cgi ########\n";
my $end_comment   = "################# End of lines added by Settings.cgi ####################\n";

my $display_splash = sub
{

    print $q->start_html(-title=>'Diogenes Settings Page',
                         -bgcolor=>'#FFFFFF'), 
    $q->start_form,
    '<center>',
    $q->h1('Your Diogenes Settings'),
    $q->p('Many settings for Diogenes can be specified in your configuration file: ', 
          "<br> $rcfile <br> To view all settings currently in effect, click here."),
    $q->table($q->Tr($q->td(
                         $q->submit(-Value=>'Show ALL current settings',
                                    -name=>'Show'),
                     ))),
        $q->p('<a href="Diogenes.cgi">Click here to return to Diogenes.</a>'),
        $q->hr,
        $q->h2('You can change some of your settings here:'),
        $q->table
        (
         $q->Tr
         (
          $q->th({align=>'right'}, 'Default corpus choice:'),
          $q->td($q->popup_menu(-name=>'cgi_default_corpus',
                                -Values=>[reverse sort keys %Diogenes::choices],
                                -Default=>$d->{cgi_default_corpus}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Provide links to Perseus morphological tool?:'),
          $q->td($q->popup_menu( -name=>'perseus_links',
                                 -Values=>[0, 1],
                                 -Labels=>{0 => 'no', 1 => 'yes'},
                                 -Default=>$d->{perseus_links}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Amount of context to show:'),
          $q->td($q->popup_menu(-name=>'context',
                                -Values=>\@Diogenes::contexts,
                                -Default=>$d->{context}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Default Greek encoding:'),
          $q->td($q->popup_menu(-name=>'cgi_default_encoding',
                                -Values=>[$d->get_encodings],
                                -Default=>$d->{cgi_default_encoding}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Number of lines per chunk to show in browser:'),
          $q->td($q->popup_menu(-name=>'browse_lines',
                                -Values=>[$d->{browse_lines}, 1..4, map {$_ * 5} (1 .. 20)],
                                -Default=>$d->{browse_lines}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Number of chunks of text to show at a time:'),
          $q->td($q->popup_menu(-name=>'browser_multiple',
                                -Values=>[1 .. 20],
                                -Default=>$d->{browser_multiple}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Greek transliteration scheme for user input:'),
          $q->td($q->popup_menu(-name=>'cgi_input_format',
                                -Values=>['Perseus-style', 'BETA code'],
                                -Default=>(($d->{cgi_input_format} =~ m/BETA/i) ? 'BETA code' : 'Perseus-style')))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The file prefix used for PHI Latin texts:'),
          $q->td($q->popup_menu(-name=>'phi_file_prefix',
                                -Values=>['lat', 'phi'],
                                -Default=>'lat'))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The location of the TLG database:'),
          $q->td($q->textfield( -name=>'tlg_dir',
                                -size=>40,
                                -maxlength=>100,
                                -Default=>$d->{tlg_dir}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The location of the PHI database:'),
          $q->td($q->textfield( -name=>'phi_dir',
                                -size=>40,
                                -maxlength=>100,
                                -Default=>$d->{phi_dir}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The location of the DDP database:'),
          $q->td($q->textfield( -name=>'ddp_dir',
                                -size=>40,
                                -maxlength=>100,
                                -Default=>$d->{ddp_dir}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Unicode font(s) to specify:'),
          $q->td($q->textfield( -name=>'unicode_font',
                                -size=>50,
                                -maxlength=>150,
                                -Default=>$d->{unicode_font}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Nearest Perseus mirror:'),
          $q->td($q->popup_menu( -name=>'perseus_server',
                                 -Values=>[keys %perseus_mirrors],
                                 -Labels=>\%perseus_mirrors,
                                 -Default=>$d->{perseus_server}))
         ),
        ),
          $q->p('To enable new settings, click below'),
          $q->table($q->Tr($q->td(
                               $q->submit(-Value=>'Save these settings',
                                          -name=>'Write'),
                           ))),
          '</center>',
          $q->end_form,
          $q->end_html;                  
};

my $display_current = sub
{
    print '<html><head><title>Diogenes Settings</title></head>
	 <body>';
    
    print '<h3>Current configuration settings for Diogenes:</h3>';
    
    my $init = new Diogenes(type => 'none');
    my $dump = Data::Dumper->new([$init], [qw(Diogenes Object)]);
    $dump->Quotekeys(0);
    $dump->Maxdepth(1);
    my $out = $dump->Dump;
    
    $out=~s/&/&amp;/g;
    $out=~s/\"/&quot;/g;
    $out=~s/>/&gt;/g;
    $out=~s/</&lt;/g;                            
    
    my @out = split /\n/, $out;
    $out[0] = $out[-1] = '';
    
    print '<pre>';
    print (join "\n", sort @out);
    print '</pre></body></html>';
};

my $write_changes = sub
{
    my $file;

    if (open RC, "<$rcfile")
    {
        local undef $/;
        $file = <RC>;
        close RC or die "Can't close $rcfile: $!\n";
    }
    $file =~ s/$begin_comment.*$end_comment//gs;
    $file .= $begin_comment;
    for my $field (@fields)
    {	
        $file .= "$field ".'"'.$q->param($field).'"'."\n";
    }
    $file .= $end_comment;
    
    open RC, ">$rcfile" or die "Can't open $rcfile: $!\n";
    print RC $file;
    close RC or die "Can't close $rcfile: $!\n";

    # Clear any provisionally set environment vars ahead of re-reading config
    Diogenes->clear_dir_env_vars(qw(tlg phi ddp));
    
    print $q->start_html(-title=>'Settings confirmed',
                         -bgcolor=>'#FFFFFF'), 
    $q->center(
        $q->h1('Settings changed'),
        $q->p("Your new settings are now in effect, and have been written to this file:<br>$rcfile"),
        $q->p('<a href="Diogenes.cgi">Click here to return to Diogenes.</a>')),
    $q->end_html;                  
};


if ($q->param('Show'))
{
    $display_current->();
}
elsif ($q->param('Write'))
{
    $write_changes->();
}
else
{
    $display_splash->();
}

