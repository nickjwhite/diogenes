################################################################################
# Diogenes is a set of programs including this Perl module which provides      
# an object-oriented interface to the CD-Rom databases published by the        
# Thesaurus Linguae Graecae and the Packard Humanities Institute.              
#                                                                              
# Send your feedback, suggestions, and cases of fine wine to                   
# P.J.Heslin@durham.ac.uk
#
#       Copyright (c) 1999-2001 Peter Heslin.  All Rights Reserved.
#       This module is free software.  It may be used, redistributed,
#       and/or modified under the terms of the GNU General Public 
#       License, either version 2 of the license, or (at your option)
#       any later version.  For a copy of the license, write to:
#
#               The Free Software Foundation, Inc.
#               675 Massachussets Avenue
#               Cambridge, MA 02139
#               USA
#
#       This module and its associated programs are distributed in the
#       hope that they will be useful, but WITHOUT ANY WARRANTY;
#       without even the implied warranty of MERCHANTABILITY or
#       FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
#       Public License for more details.
################################################################################

package Diogenes;
require 5.005;

$Diogenes::Version =  "1.4.4";
$Diogenes::my_address = 'P.J.Heslin@durham.ac.uk';

use strict;
use integer;
use Cwd;
use Carp;
#use Data::Dumper;

eval "require 'Diogenes.map';";
$Diogenes::map_error = $@;
# Add in the built-in encodings
$Diogenes::encoding{Beta} = {};
$Diogenes::encoding{Ibycus} = {};
$Diogenes::encoding{Transliteration} = {};
use vars qw($RC_DEBUG);
$RC_DEBUG = 0;

# Define some globals
$Diogenes::context{g} = {
    'sentence'  => '[.;]',
    'clause'    => '[.;:]',
    'phrase'    => '[.;:,_]', 
    'paragraph' => '[@{}]'
    };
$Diogenes::context{l} = {
    'clause'    => '[.!?;:]',
    'sentence'  => '[.!?]',
    'phrase'    => '[.!?;:,_]',
    'paragraph' => '[@{}<>]'
    };

@Diogenes::contexts = (
    'paragraph',
    'sentence',
    'clause',
    'phrase',
    '1 line',
    '2 lines',
    '5 lines',
    '10 lines',
    '50 lines',
);

# These are the choices presented (e.g. on the opening CGI page).  If you do
# not have all of these CD-Roms, or if you wish to disallow one or more of
# these searches, comment lines out of this list.

%Diogenes::choices =  (
    'PHI Latin Corpus' => 'phi',
    'TLG Word List' => 'tlg',
    'TLG Texts' => 'tlg',
    'TLG Bibliography', => 'bib',
    'Duke Documentary Papyri' => 'ddp',
    'Classical Inscriptions (Latin)' =>'ins',
    'Classical Inscriptions (Greek)' =>'ins',
    'Christian Inscriptions (Latin)' => 'chr',
    'Christian Inscriptions (Greek)' => 'chr',
    'Miscellaneous PHI Texts (Greek)' => 'misc',
    'Miscellaneous PHI Texts (Latin)' => 'misc',
    'PHI Coptic Texts' => 'cop',
);
# Here are some handy constants

use constant MASK     => hex '7f';
use constant RMASK    => hex '0f';
use constant LMASK    => hex '70';
use constant OFF_MASK => hex '1fff';
$| = 1;

my ($authtab, $tlgwlinx, $tlgwlist, $tlgwcinx, $tlgwcnts, $tlgawlst);
my @tlg_files = 
    ('authtab.dir', 'tlgwlinx.inx', 'tlgwlist.inx', 'tlgwcinx.inx', 
     'tlgwcnts.inx', 'tlgawlst.inx');

{   # For closure
    # Default values for all Diogenes options.
    # Overridden by rc files and constructor args.
    
    my %defaults = (
        type => 'phi',
        output_format => 'ascii',
        highlight => 1,
        printer => 0,
        input_lang => 'l',
        input_raw => 0,
        input_pure => 0,
        input_beta => 0,
        debug => 0,
        bib_info => 1,
        max_context => 100,
        encoding => '',
        
        # System-wide defaults
        tlg_dir => '/mnt/cdrom/',
        phi_dir => '/mnt/cdrom/',
        ddp_dir => '/mnt/cdrom/',
        tlg_file_prefix => 'tlg',
        phi_file_prefix => 'lat',
        ddp_file_prefix => 'ddp',
        ins_file_prefix => 'ins',
        chr_file_prefix => 'chr',
        cop_file_prefix => 'cop',
        misc_file_prefix => 'civ',
        uppercase_files => 0,
        dump_file => '', 
        blacklist_file => '', 
        blacklisted_works_file => '', 
        ibycus4 => 0,
        prosody => 0,
        psibycus => 0,
        idt_suffix => '.idt',
        txt_suffix => '.txt',
        latex_pointsize => '',
        latex_baseskip => '',
        latex_counter => 1,
        use_tlgwlinx => 1,
        
        # Lines per pass in browser ...
        browse_lines => 29,
        # ... and number of passes
        browser_multiple => 1,
        
        # Pattern to match
        pattern => '',
        pattern_list => [],
        min_matches => 1,
        context => 'sentence',
        reject_pattern => '',
        
        # The max number of lines for different types of context
        overflow => {
            'sentence'      => 30,
            'clause'        => 5,
            'phrase'        => 3,
            'paragraph'     => 100,
        },
        
        # Additional file handle to write raw output to 
        aux_out => undef,
        input_source => undef,
        
        # Default instruction for dumb browsers
        unicode_font => 'Arial Unicode MS, TITUS Cyberbit Basic, '.
        'Porson, Athena',
        
        coptic_encoding => 'UTF-8',
        
        #### CGI initialization ####
        
        # directory and prefix for the temp files we generate.
        cgi_tmp_dir => '/tmp',
        cgi_prefix => 'diogenes.',
        
        cgi_root_dir => '',
        cgi_img_dir_absolute => 'c:\\diogenes/gifs/',
        cgi_img_dir_relative => '/gifs/',
        
        cgi_gs  => '/usr/bin/gs',
        cgi_p2g => '/usr/bin/ppmtogif',
        cgi_latex => '/usr/bin/latex',
        cgi_ps2pdf => '/usr/bin/ps2pdf',
        cgi_dvips => '/usr/bin/dvips',
        cgi_check_mod_perl => 0,
        cgi_enable_latex => 0,
        cgi_latex_word_list => 0,
        
        cgi_input_format => 'Perseus', # default: Perseus
        cgi_default_corpus => 'TLG Word List', 
        cgi_default_encoding => 'UTF-8', 
        cgi_buttons => 'Go to Context', 
        cgi_default_criteria => 'All',
        
        perseus_links => 1, # links to Perseus morphological parser 
        perseus_server => 'http://www.perseus.tufts.edu/',
        perseus_target => 'morph',
        
        quiet => 0,
        # deprecated
        cgi_pdflatex => undef,
    );
        
    my $validate = sub 
    {
        my $key = shift;
        $key =~ s/-?(\w+)/\L$1/;
        return $key if exists $defaults{$key};
        die ("Configuration file error in parameter: $key\n");
    };
                
    # UNIX - Local config files in home and cwd override the global file in /etc
    my @rc_files = ('/etc/diogenesrc');
    push @rc_files, "$ENV{HOME}/.diogenesrc" if $ENV{HOME};
    my $cwd = cwd;
    push @rc_files, "$cwd/.diogenesrc";
    
    # MS Win -- Only config file is .ini in current folder
    @rc_files = ("$cwd\\diogenes.ini") if ($^O =~ /MSWin|dos/);
    
    my (%rc_defaults, $attrib, $val);
                
    foreach my $rc_file (@rc_files) 
    {
        next unless $rc_file;
        print STDERR "Trying config file: $rc_file ... " if $RC_DEBUG;
        next unless -e $rc_file;
        open RC, "<$rc_file" or die ("Can't open (apparently extant) file $rc_file: $!");
        print STDERR "Opened.\n" if $RC_DEBUG;
        while (<RC>) 
        {
            next if m/^#/;
            next if m/^\s*$/;
            ($attrib, $val) = m#^\s*(\w+)[\s=]+((?:"[^"]+"|[\S]+)+)#;
            $val =~ s#"([^"]*)"#$1#g;
            print STDERR "parsing $rc_file for '$attrib' = '$val'\n" if $RC_DEBUG;
            die "Error parsing $rc_file for $attrib and $val: $_\n" unless 
                $attrib and defined $val;
            $attrib = $validate->($attrib);
            $rc_defaults{$attrib} = $val;   
        }
        close RC or die ("Can't close $rc_file");
    }

    sub new 
    {
        my $proto = shift;
        my $type = ref($proto) || $proto;
        my $self = {};
        bless $self, $type;
        
        my %args;
        my %passed = @_;
        $args{ $validate->($_) } = $passed{$_} foreach keys %passed;
        
        %{ $self } = ( %{ $self }, %defaults, %rc_defaults, %args );
        
        # Clone values that are references, so we don't clobber what was passed.
        $self->{pattern_list} = [@{$self->{pattern_list}}] if $self->{pattern_list};
        $self->{overflow}     = {%{$self->{overflow}}}     if $self->{overflow};
        
        $self->{type} = 'tlg' if ref $self eq 'Diogenes_indexed';

        # Make sure all the directories end in a '/'
        my @dirs = qw/tlg_dir phi_dir ddp_dir cgi_tmp_dir 
                      cgi_img_dir_absolute cgi_img_dir_relative/;
        for my $dir (@dirs)
        {
            $self->{$dir} .= '/' unless $self->{$dir} =~ m#[/\\]$#;
        }
        
        unless ($self->{type} eq 'none')
        {
            $self->{word_key} = "";
            $self->{current_work} = 0;
            $self->{word_list} = {};
            $self->{auth_num} = 0;
            $self->{work_num} = 0;
            $self->{list_total} = 0;
        }
        print STDERR "\nTYPE: $self->{type}\n" if $self->{debug};
        # Dummy object where no database access is desired -- e.g. to get at 
        # configuration values or to format some Greek input from elsewhere.
        if ($self->{type} eq 'none') 
        {
            $self->{cdrom_dir}   = undef;
            $self->{file_prefix} = "";
        }
        # PHI
        elsif ($self->{type} eq 'phi') 
        {
            $self->{cdrom_dir}   = $self->{phi_dir};
            $self->{file_prefix} = $self->{phi_file_prefix};
            $self->make_latin_pattern;      
        }
        
        # TLG
        elsif ($self->{type} eq 'tlg') 
        {
            $self->{cdrom_dir}   = $self->{tlg_dir};
            $self->{file_prefix} = $self->{tlg_file_prefix};
            if (ref $self eq 'Diogenes_indexed') 
            {    # Can also pass this as an arg to read_index.
                $self->{pattern} = $self->simple_latin_to_beta ($self->{pattern});
            }
            else 
            {
                $self->make_greek_pattern;
            }
        }
        
        # DDP
        elsif ($self->{type} eq 'ddp') 
        {
            $self->{cdrom_dir}   = $self->{ddp_dir};
            $self->{file_prefix} = $self->{ddp_file_prefix};
            $self->make_greek_pattern;
            $self->{documentary} = 1;
        }

        # INS
        elsif ($self->{type} eq 'ins') 
        {
            $self->{cdrom_dir}   = $self->{ddp_dir};
            $self->{file_prefix} = $self->{ins_file_prefix};
            $self->{documentary} = 1;
            if ($self->{input_lang} =~ /^g/i)   
            { 
                $self->make_greek_pattern; 
            }
            else 
            { 
                $self->make_latin_pattern;
            }
        }
        # CHR
        elsif ($self->{type} eq 'chr') 
        {
            $self->{cdrom_dir}   = $self->{ddp_dir};
            $self->{file_prefix} = $self->{chr_file_prefix};
            $self->{documentary} = 1;
            if ($self->{input_lang} =~ /^g/i)       
            { 
                $self->make_greek_pattern; 
            }
            else 
            { 
                $self->make_latin_pattern;
            }
        }

        # COP
        elsif ($self->{type} eq 'cop') 
        {
            $self->{cdrom_dir}   = $self->{ddp_dir};
            $self->{file_prefix} = $self->{cop_file_prefix};
            $self->{latin_handler} = \&beta_latin_to_utf;
            $self->{coptic_encoding} = 'beta' if 
                $args{output_format} and $args{output_format} eq 'beta';
        }
        
        # CIV
        elsif ($self->{type} eq 'misc') 
        {
            $self->{cdrom_dir}   = $self->{phi_dir};
            $self->{file_prefix} = $self->{misc_file_prefix};
            if ($self->{input_lang} =~ /^g/i)       
            { 
                $self->make_greek_pattern; 
            }
            else 
            { 
                $self->make_latin_pattern;
            }
        }
        # BIB
        elsif ($self->{type} eq 'bib') 
        {
            $self->{cdrom_dir}   = $self->{tlg_dir};
            $self->{file_prefix} = 'doccan';
        }
        else 
        {
            die ("I did not understand the type => $self->{type}\n");
        }
        
        # Evidently some like to mount their CD-Roms in uppercase
        ($authtab, $tlgwlinx, $tlgwlist, $tlgwcinx, $tlgwcnts, $tlgawlst) = 
            $self->{uppercase_files} ? map {uc $_} @tlg_files : @tlg_files;
        if ($self->{uppercase_files})
        {
            $self->{$_} = uc $self->{$_} for 
                qw(file_prefix txt_suffix cdrom_dir idt_suffix);
        }

        # For all searches:
                
        if (exists $self->{pattern}
            and not exists $self->{pattern_list})
        {
            $self->{pattern_list} = [$self->{pattern}];
            $self->{min_matches_int} = 1;
        }
        elsif ($self->{pattern})
        {
            push @{ $self->{pattern_list} }, $self->{pattern};
        }
        $self->{word_pattern} = $self->{pattern};
        
        # min_matches_int is for "internal", since we have to munge it here
        $self->{min_matches_int} = '';
        unless (ref $self eq 'Diogenes_indexed')
        {
            $self->{min_matches_int} = $self->{min_matches};
            $self->{min_matches_int} = 1 if $self->{min_matches} eq 'any';
            $self->{min_matches_int} =  scalar @{ $self->{pattern_list} } if 
                $self->{min_matches} eq 'all';
        }
        print STDERR "MM: $self->{min_matches}\n" if $self->{debug};
        print STDERR "MMI: $self->{min_matches_int}\n" if $self->{debug};
        
        $self->{context} = $1 if 
            $self->{context} =~ /(sentence|paragraph|clause|phrase|\d+\s*(?:lines)?)/i;
        $self->{context} = lc $self->{context};
        die "Undefined value for context.\n" unless defined $self->{context};
        die "Illegal value for context: $self->{context}\n" unless 
            $self->{context} =~ 
            m/^(?:sentence|paragraph|clause|phrase|\d+\s*(?:lines)?)$/;
        $self->{numeric_context} = ($self->{context} =~ /\d/) ? 1 : 0;
        print STDERR "Context: $self->{context}\n" if $self->{debug};

        # Check for external encoding
        die "You have asked for an external output encoding ($self->{encoding}), "
            . "but I was not able to load a Diognes.map file in which such encodings "
            . "are defined: $Diogenes::map_error \n"  
            if  $self->{encoding} and $Diogenes::map_error;
        die "You have specified an encoding ($self->{encoding}) that does not "
            . "appear to have been defined in your Diogenes.map file.\n\n"
            . "The following Greek encodings are available:\n"
            . (join "\n", $self->get_encodings)
            . "\n\n"
            if $self->{encoding} and not exists $Diogenes::encoding{$self->{encoding}};

        # Some defaults       
        if (not $self->{encoding})
        {
            # force encoding Ibycus for repaging output removing hyphens and
            # using TLG non-ascii markers for section references.  PAM 090102
            $self->{encoding} = 'Ibycus' if $self->{output_format} =~ m/repaging/i;
            $self->{encoding} = 'Ibycus' if $self->{output_format} =~ m/latex/i;
            $self->{encoding} = 'Transliteration' if $self->{output_format} =~ m/ascii/i;
            $self->{encoding} = 'UTF-8' if $self->{output_format} =~ m/html/i;
            $self->{encoding} = 'Beta' if $self->{output_format} =~ m/beta/i;
        }

        $self->set_handlers;    
        
        $self->{perseus_server} .= '/' unless $self->{perseus_server} =~ m#/$#; 

        print STDERR "Using prefix: $self->{file_prefix}\nUsing pattern(s): ",
        join "\n", @{ $self->{pattern_list} }, "\n" if $self->{debug};
        print STDERR "Using reject pattern: $self->{reject_pattern}\n" if 
            $self->{debug} and $self->{reject_pattern};
        
        # Read in some preliminary data, except for a dummy object
        if (($self->{type} eq 'none') or ($self->parse_authtab))
        {
            if ($self->{bib_info})
            {
                $self->read_tlg_biblio if $self->{type} eq 'tlg';
                $self->read_phi_biblio if $self->{type} eq 'phi';
            }
            return $self;
        }
        else
        {
            warn   "Error: $self->{cdrom_dir}$authtab was not found!\n";
            return "$self->{cdrom_dir}";
        }
    }
} # End closure

sub set_handlers
{
    my $self = shift;
    
    if ($self->{encoding} =~ m/Beta/i)
    {
        $self->{greek_handler} = sub { return shift };
        $self->{latin_handler} = sub { return shift };
    }
    elsif ($self->{encoding} =~ m/Ibycus/i)
    {
        print STDERR "Ibycus encoding\n" if $self->{debug};
        $self->{greek_handler} = sub { beta_encoding_to_ibycus($self, shift)} ;
        $self->{latin_handler} = \&beta_encoding_to_latin1;
    }
    elsif ($self->{encoding} =~ m/Transliteration/i)
    {
        print STDERR "Transliteration encoding\n" if $self->{debug};
        $self->{greek_handler} = sub { beta_encoding_to_transliteration($self, shift)} ;
        $self->{latin_handler} = \&beta_encoding_to_latin1;
    }
    elsif ($self->{encoding} =~ m/ISO_8859_7/i)
    {
        $self->{greek_handler} = sub { beta_encoding_to_external($self, shift) }; 
        $self->{latin_handler} = sub { return shift };
    }
    elsif ($self->{encoding} =~ m/Babel/i)
    {
        $self->{greek_handler} = sub { beta_encoding_to_external($self, shift) }; 
        $self->{latin_handler} = \&beta_encoding_to_latin_tex;
    }
    elsif ($self->{encoding} =~ m/utf/i)
    {
        $self->{greek_handler} = sub { beta_encoding_to_external($self, shift) }; 
        $self->{latin_handler} = \&beta_latin_to_utf;
    }
    # The fall-back
    elsif (defined $Diogenes::encoding{$self->{encoding}})
    {
        $self->{greek_handler} = sub { beta_encoding_to_external($self, shift) }; 
        $self->{latin_handler} = \&beta_encoding_to_latin1;
    }
    else 
    {
        die "I don't know what to do with $self->{encoding}!\n";
    }

#       if ($self->{output_format} =~ m/html/i)
#       {
#               # Note that null chars need to stay in until the html or whatever is done.
#               # We make this a no-op instead of generating latin-1, because Netscape under
#               # Windows doesn't handle those chars properly with a Unicode font.
##              $self->{latin_handler} = sub {return shift };
#               $self->{latin_handler} = sub { beta_encoding_to_html($self, shift) };
#       }
#       if ($self->{output_format} =~ m/ascii/i)
#       {
#               $self->{latin_handler} = sub { beta_encoding_to_latin1(shift) };
#       }

}

sub set_perseus_links
{   # Set up links to Perseus morphological parser 
    my $self = shift;
    $self->{perseus_morph} = 0 ; 
    $self->{perseus_morph} = 1 if 
        $self->{perseus_links} and $self->{output_format} =~ m/html/; 
    $self->{perseus_morph} = 0 if $self->{type} eq 'cop';
    $self->{perseus_morph} = 0 if $self->{encoding} =~ m/babel/i;
}       

# Restricts the authors and works in which to search according to the
# settings passed, and returns those authors and works.
sub select_authors 
{
    my $self = shift;
    my %passed = @_;
    my (%args, %req_authors, %req_a_w, %req_au, %req_auth_wk);
    my ($file, $baseline);
    
    $self->parse_lists if $self->{type} eq 'tlg' and not %Diogenes::list_labels;
        
    # A call with no params returns all authors.
    return $Diogenes::auths{$self->{type}} if (! %passed); 
    
    # This is how we get the categories into which the TLG authors are divided
    die "Only the TLG categorizes text by genre, date, etc.\n" 
        if $args{'get_tlg_categories'} and $self->{type} ne 'tlg';
    return \%Diogenes::list_labels if $passed{'get_tlg_categories'};
    
    my @universal = (qw(criteria author_regex author_nums select_all previous_list) );
    my @other_attr = ($self->{type} eq 'tlg') ? keys %Diogenes::list_labels : ();
    my %valid = map {$_ => 1} (@universal, @other_attr);
    my $valid = sub 
    {
        my $key = shift;
        $key =~ s/-?(\w+)/\L$1/;
        return $key if exists $valid{$key};
        die ("I did not understand the parameter: $key\n");
    };
    
    $args{ $valid->($_) } = $passed{$_} foreach keys %passed;
    
    if ($args{'select_all'}) 
    {
        undef $self->{req_authors};
        undef $self->{req_auth_wk};
        undef $self->{filtered};
        undef @ARGV;
        return $Diogenes::auths{$self->{type}};
    }
        
    $self->{filtered} = 1;
    foreach my $k (keys %args) 
    {
        if ($k eq 'criteria') 
        {
            # do nothing
        }
        elsif ($k eq 'author_regex') 
        {
            $req_authors{ $_ }++ foreach
                keys %{ $self->match_authtab($args{$k}) };
        }                
        elsif ($k eq 'date') 
        {
            my ($start_date, $end_date, $var_flag, $incert_flag) = @{ $args{$k} };
            my ($start, $end, $varia, $incertum);
            my $n = 0;
            foreach (@{ $Diogenes::list_labels{date} })
            {
                $start = $n if $_ eq $start_date;
                $end = $n if $_ eq $end_date;
                $varia = $n if $_ =~ /vari/i;
                # Note the space at the end of Incertum
                $incertum = $n if $_ =~ /incert/i;
                $n++;
            }
            $start = 0 if $start_date =~ /--/;
            $end = length @{ $Diogenes::list_labels{date} } - 1 if $end_date =~ /--/;
            my @dates = ($start .. $end);
            push @dates, $varia if $var_flag;
            push @dates, $incertum if $incert_flag;
            
            foreach my $date (@{ $Diogenes::list_labels{date} }[@dates]) 
            {
                $req_authors{$_}++ foreach @{ $Diogenes::lists{'date'}{$date} };
            }
        }
                        
        elsif ($k eq 'author_nums') 
        {
            if (ref $args{$k} eq 'ARRAY')
            {
                foreach my $a (@{ $args{$k} }) 
                {
                    my $auth = sprintf '%04d', $a;
                    $req_authors{$auth}++ ;
                }
            }
            elsif (ref $args{$k} eq 'HASH')
            {
                foreach my $a (keys %{ $args{$k} })
                {
                    my $auth = sprintf '%04d', $a;
                    $req_authors{$auth}++, next unless ref $args{$k}{$a};
                    $self->{check_word_stats} = 1;
                    foreach my $w (@{ $args{$k}{$a} })
                    {
                        my $work = sprintf '%03d', $w;
                        $req_auth_wk{$auth}{$work}++;
                    }
                }
            }
            else { die 'Error on parsing author_nums parameter' }
        }
        
        elsif ($k eq 'previous_list') 
        {
            die "You asked for a subset of the previous list, ".
                "but I have no record of such." unless $self->{prev_list};
            
            my ($au, $wk);
            foreach my $index (@{ $args{$k} }) 
            {
                die "You seem to have pointed to a non-extant ".
                    "member of the previous list" unless $self->{prev_list}[$index];
                if (ref $self->{prev_list}[$index]) 
                {
                    $self->{check_word_stats} = 1;
                    ($au, $wk) = @{ $self->{prev_list}[$index] };
                    $req_auth_wk{$au}{$wk}++;
                }
                else
                {
                    $au = $self->{prev_list}[$index];
                    $req_authors{$au}++;    
                }
            }
            delete $self->{prev_list};
        }

        else 
        {
            undef %req_au;
            undef %req_a_w;
            foreach my $x (map $Diogenes::lists{$k}{$_},  @{ $args{$k} }) 
            {
                if (ref $x eq 'ARRAY') 
                {
                    $req_au{$_}++ foreach @{ $x };
                }
                elsif (ref $x eq 'HASH')
                {
                    $self->{check_word_stats} = 1;
                    foreach my $au (keys %{ $x }) 
                    {
                        $req_a_w{$au}{$_}++ foreach @{ $x->{$au} };
                    }
                }
                else {  die "Error parsing argument $k => (". 
                            (join ', ', @{ $args{$k} }) .")"; }
            }
            
            # Eliminate duplicate hits on same author or work as selected via
            # different values of the same criterion
            $req_authors{$_}++ foreach keys %req_au;
            foreach my $au (keys %req_a_w) 
            {
                $req_auth_wk{$au}{$_}++ foreach keys %{ $req_a_w{$au} };
            }
        }
    }       
        
    # This makes `or' rather than `and' the default.  Better?
    $args{'criteria'} = 1 unless exists $args{'criteria'};
    $args{'criteria'} = ((keys %args) - 1) if 
        $args{'criteria'} =~ m/all/i; #the 1 is 'criteria' itself
    $args{'criteria'} = 1 if $args{'criteria'} =~ m/any/i;
    print STDERR "Criteria: ", $args{criteria}, "\n" if $self->{debug};
    
    # Eliminate auths & works that don't meet enough criteria
    undef $self->{req_auth_wk};
    undef $self->{req_authors};
    foreach (keys %req_authors) 
    {
        $self->{req_authors}{$_}++ if $req_authors{$_} >= $args{'criteria'};
    }               
    foreach my $au (keys %req_auth_wk) 
    {
        next if $self->{req_authors}{$au}; # already added to the list
        foreach my $wk ( keys %{ $req_auth_wk{$au} } ) 
        {
            local $^W;
            $self->{req_auth_wk}{$au}{$wk}++ if 
                ((0 + $req_authors{$au}) + (0 + $req_auth_wk{$au}{$wk}) 
                 >= $args{'criteria'});
        }
    }
    print STDERR Data::Dumper->Dump ([\$self->{req_authors}, \$self->{req_auth_wk}], 
                                     ['req_authors', 'req_auth_wk']) if $self->{debug};
        
    @ARGV = ();
    # Only put into @ARGV those files we want to search in their entirety!
    foreach my $au (keys %{ $self->{req_authors} }) 
    {
        $file = $self->{file_prefix} . (sprintf '%04d', $au) . $self->{txt_suffix};
        push @ARGV, $file;
    }
    # print "\nusing \@ARGV: ", Data::Dumper->Dump ([\@ARGV], ['*ARGV']);
    die "There were no texts matching your criteria" unless 
        @ARGV or $self->{req_auth_wk};
    
    return unless wantarray;
    
    # return auth & work names
    my ($basename, @ret);
    my $index = 0;
    my %auths = %{ $Diogenes::auths{$self->{type}} };
    $self->format_output(\$auths{$_}, 'l') for keys %auths;
    foreach my $auth (sort numerically keys %{ $self->{req_authors} }) 
    {
        push @ret, "$auths{$auth}: All texts";
        $self->{prev_list}[$index++] = $auth;
    }
    foreach my $auth (sort numerically keys %{ $self->{req_auth_wk} }) 
    {
        $basename = $auths{$auth};
        my $real_num = $self->parse_idt($auth);
        foreach my $work ( sort numerically keys %{ $self->{req_auth_wk}{$auth} } ) 
        {
            my $wk_name = $Diogenes::work{$self->{type}}{$real_num}{$work};
            $self->format_output(\$wk_name, 'l');
            push @ret, "$basename: $wk_name";
            $self->{prev_list}[$index++] = [$auth, $work];
        }
    }
    return @ret;
}

sub do_search 
{
    my $self = shift;
    
    $self->set_perseus_links; 
    
    # Do the search (brute force).
    $self->begin_boilerplate;
    $self->pgrep;
    $self->print_totals;
    $self->end_boilerplate;
}

sub do_format
{
    my $self = shift;
    $self->begin_boilerplate;
    
    $self->set_perseus_links; 
    
    die "You must specify an input_source for do_format!\n" unless $self->{input_source};
    die "input_source should be a reference!\n" unless ref $self->{input_source};
    my $input = $self->{input_source};
    my $ref = ref $input;
    my $inp;
    if ($ref eq 'SCALAR')
    {
        $inp = $input;
        $self->format_output(\$inp);
        print $inp;
    }
    elsif ($ref eq 'ARRAY')
    {
        for (@{$input})
        {
            my $inp = $_;
            $self->format_output(\$inp);
            print $inp;
        }
    }
    elsif ($ref eq 'CODE')
    {
        while ($input->())
        {
            my $inp = $_;
            $self->format_output(\$inp);
            print $inp;
        }
    }
    else
    {
        local $/ =  "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
        my $holder = $self->{latex_counter};
        $self->{latex_counter} = 0;
        while (<$input>)
        {
            my $inp = $_;
            $self->format_output(\$inp);
            print $inp;
        }
        $self->{latex_counter} = $holder;
    }
    
    $self->end_boilerplate;
    
}

sub get_encodings
{
    return sort keys %Diogenes::encoding;
}

sub encode_greek
{
    my ($self, $enc, $ref) = @_;
    my $old_encoding = $self->{encoding};
    $self->{encoding} = $enc;
    $self->set_handlers;
    $self->greek_with_latin($ref);
    $$ref =~ s/ˇˇø/"/g;
    $$ref =~ s/ˇˇ%/%/g;
    $self->{encoding} = $old_encoding;
    $self->set_handlers;
}


###############################################################################
#-----------------------------------------------------------------------------#
#---------------- Only private subs and methods below ------------------------#
#-----------------------------------------------------------------------------#
###############################################################################

#########################################################################
#                                                                       #
# Parse list3cla.bin, etc. for genre, date, etc. info.  Only useful for #
# tlg searches.                                                         #
#                                                                       #
#########################################################################

sub parse_lists 
{
    my $self = shift;
    my @tlg_class_files = 
        ( qw(list3cla.bin list3clx.bin list3dat.bin list3epi.bin 
             list3fem.bin list3geo.bin) );
    my @tlg_classifications = 
        ( qw(genre genre_clx date epithet gender location) );
    if ($self->{uppercase_files}) 
    {
        @tlg_class_files = map {uc($_)} @tlg_class_files ;
    }
    
    my ($base_ptr, $ptr, $label, $j, $ord, $auth_num, @works, $old);
    my ($type, $high);
    my $d = 0;
    foreach my $file (@tlg_class_files) 
    {
        $type = shift @tlg_classifications;
        
        open BIN, "<$self->{cdrom_dir}$file" or die ("couldn't open $file: $!");
        binmode BIN;
        local $/;
        undef $/;
        
        my $buf = <BIN>;
        
        $base_ptr = unpack 'N', substr ($buf, 0, 4);
        my $i = 4;
                
        while ($i <= length $buf) 
        {
            $ptr = $base_ptr + unpack 'N', substr ($buf, $i, 4);
            $i += 4;
            
            last if ord (substr ($buf, $i, 1)) == 0;
            
            $label = Diogenes::get_pascal_string(\$buf, \$i);       
            $self->beta_formatting_to_ascii(\$label, 'l') if $type eq 'date';
            $i++;
            push @{ $Diogenes::list_labels{$type} }, $label;
            $j = $ptr;
            $ord = ord (substr ($buf, $j, 1));
            
            until ($ord == 0) 
            {
                $auth_num = (unpack 'n', substr ($buf, $j, 2)) & hex '7fff';
                $auth_num = sprintf '%04d', $auth_num;
                $j += 2;
                $ord = ord (substr ($buf, $j, 1));
                
                if ( ($ord & hex '80') or ($ord == 0) ) 
                {
                    push @{ $Diogenes::lists{$type}{$label} }, $auth_num;
                    next;
                }
                @works = ();
                $old = 0;       
                until ( ($ord & hex '80') or ($ord == 0) ) 
                {
                    if ( $ord < hex '20' ) 
                    {
                        push @works, $ord;
                        $old = $ord;
                    }
                    elsif ( $ord == hex '20' ) 
                    {
                        die "Ooops while parsing $file at $j" if $ord & hex '20';
                    }
                    elsif ( $ord < hex '40' ) 
                    {
                        push @works, (($old + 1) .. ($old + ($ord & hex '1f')));
                        $old = 0;
                    }
                    elsif ( $ord < hex '60' ) 
                    {
                        die "Ooops while parsing $file at $j\n" if $ord & hex '20';
                        $high = ($ord & hex '01') << 8; 
                        $j++;
                        $ord = ord (substr ($buf, $j, 1));
                        $old = $high + $ord;
                        push @works, $old;
                    }
                    elsif ( $ord == hex '60' ) 
                    {
                        $j++;
                        $ord = ord (substr ($buf, $j, 1));
                        push @works, (($old + 1) .. ($ord + 1));
                    }
                    else 
                    {
                        die "Oops while parsing $file at $j";
                    }
                    
                    $j++;
                    $ord = ord (substr ($buf, $j, 1));
                }
                push @{ $Diogenes::lists{$type}{$label}{$auth_num} }, 
                map {sprintf '%03d', $_ } @works;
            }
        }
        close BIN;
    }
}

######################################################################
#                                                                    #
# Parse the author names in authtab.dir and store the                #
# matches as a reference to a hash keyed by author numbers.  Also    #
# determines the fundamental language of each text file.             #
#                                                                    #
######################################################################

sub parse_authtab 
{
    my $self = shift;
    my $prefix = "\U$self->{file_prefix}\E";
    my (%auths, $file_num, $base_lang);
    
    # Maybe CD-Rom is not mounted yet
    return undef unless -e $self->{cdrom_dir}."authtab.dir";
    
    open AUTHTAB, $self->{cdrom_dir}.$authtab or 
        $self->barf("Couldn't open $self->{cdrom_dir}$authtab");
    binmode AUTHTAB;
    local $/ = "\xff";
                        
    my $regexp = qr!$prefix(\w\w\w\d)\s+([\x01-\x7f]*[a-zA-Z][^\x83\xff]*)!;
    
    while (my $entry = <AUTHTAB>)
    {
        # get new base language if this is a new prefix group: e.g. *CIV.
        $base_lang = $1 if $entry =~ m/^\*$prefix[^\x83]*\x83(\w)\xff/;
        # English uses the Latin alphabet, or so I've heard.
        # Don't know what to do with Hebrew yet.
        $base_lang = 'l' if defined $base_lang and ($base_lang eq 'e'
                                                    or $base_lang eq 'h');
        
        # get auth num and name
        my ($file_num, $name) = $entry =~ $regexp;
        next unless defined $file_num;
        $file_num =~ tr/A-Z/a-z/; # doccanx.txt
        # Get rid of non-ascii stuff
        $name =~ s#[\x80-\xff]+# #g;
        #$self->format_output (\$name, 'l'); #no, no here, takes too much time
        
        $auths{$file_num} = $name; 
        
        # get deviant lang, if any, of this particular entry 
        my ($lang) = $entry =~ m/\x83(\w)/;
        $lang = 'l' if defined $lang and ($lang eq 'e' or $lang eq 'h');
        $Diogenes::lang{$self->{type}}{$file_num} = (defined $lang) ? $lang : $base_lang;
    }
    if (keys %auths == 0 and $self->{type} ne 'bib')
    {
        warn "No matching files found in authtab.dir: \n",
        "Is $prefix the correct file prefix for this database?\n";
        return undef;
    }
    close AUTHTAB;
    #print STDERR Dumper \%auths if $self->{debug};
    #print STDERR Dumper $Diogenes::lang if $self->{debug};
    
    $Diogenes::auths{$self->{type}} = \%auths;
    return 1;
}

# Extract a given pattern from the authtab info read in above
sub match_authtab
{
    my $self = shift;
    my $big_pattern = shift;
    utf8_to_beta_encoding(\$big_pattern);
    $big_pattern ||= '.';            # Avoid warnings on null pattern
    my %total = ();
    my %auths;
    $self->parse_authtab unless $Diogenes::auths{$self->{type}};
    die "Unable to get author info from the authtab.dir file!\n" unless 
        $Diogenes::auths{$self->{type}};

    for my $pattern (split /[\s,]+/, $big_pattern)
    {
        print STDERR "pattern: $pattern\n" if $self->{debug};

        if ($pattern =~ /\D/)
        {       # Search values (auth names)
            %auths = map { $_ => $Diogenes::auths{$self->{type}}{$_} }
            grep $Diogenes::auths{$self->{type}}{$_} =~ /$pattern/i,
            keys %{ $Diogenes::auths{$self->{type}} };
        }
        else
        {       # Search keys (auth nums)
            $pattern = sprintf '%04d', $pattern; 
            %auths = map { $_ => $Diogenes::auths{$self->{type}}{$_} }
            grep /$pattern/, keys %{ $Diogenes::auths{$self->{type}} };
        }
        (%total) = (%total, %auths);
    }
    # Strip formatting
    $self->format_output(\$total{$_}, 'l') for keys %total;
    return \%total;
}

###########################################################
#                                                         #
# Method to print the total hits in a brute force search. #
#                                                         #
###########################################################

sub print_totals 
{
    my $self = shift;
    my $out = '';
    $out .= '\nrm{}' if $self->{output_format} eq 'latex';
    $out .= "\n\&Passages found: " . ($self->{hits} || 0) ."\n";
    $out .= '(' . $self->{blacklisted_hits} .
        " passages suppressed from blacklisted works)\n" 
        if $self->{blacklisted_hits};
    $out .= '(' . $self->{blacklisted_files} .
        " blacklisted authors were not searched at all)\n" 
        if $self->{blacklisted_files};
    $out .= "\n";
    $self->print_output(\$out);
}

sub make_greek_pattern 
{
    my $self = shift;

    if ($self->{input_beta})
    {
        $self->{reject_pattern} = $self->beta_to_beta ($self->{reject_pattern});
    }
    elsif ($self->{input_raw})
    {
        $self->{reject_pattern} = quotemeta $self->{reject_pattern};
    }
    elsif (not $self->{input_pure})
    {
        $self->{reject_pattern} = $self->latin_to_beta($self->{reject_pattern});
    }
    
    foreach my $pat (@{ $self->{pattern_list} })
    {
        if ($self->{input_pure}) 
        { 
            $pat = $pat;
        }
        elsif ($self->{input_raw}) 
        { 
            $pat = quotemeta $pat;
        }
        elsif ($self->{input_beta})
        {
            $pat = $self->beta_to_beta ($pat);
        }
        else 
        {
            $pat = $self->latin_to_beta ($pat);
        }
    }
}

# Input a raw BETA word, and this makes a TLG word-list style regexp
sub beta_to_beta
{
    my ($self, $pat) = @_;
    $pat =~ tr/a-z/A-Z/;                    # upcap all letters
    $pat =~ s#\\#/#g;                       # normalize accents
    my ($begin, $end) = (0, 0);
    $begin = 1 if $pat =~ s#^\s+##;
    $end   = 1 if $pat =~ s#\s+$##;
    ($pat, undef) = 
        Diogenes_indexed::make_tlg_regexp($self, $pat, (not $begin), (not $end));
    return $pat;
}

sub make_latin_pattern
{
    my $self = shift;
        
    $self->{reject_pattern} = $self->latin_pattern($self->{reject_pattern});
    foreach my $pat (@{ $self->{pattern_list} })
    {
        if ($self->{input_pure}) 
        { 
            $pat = $pat;
        }
        elsif ($self->{input_raw}) 
        { 
            $pat = quotemeta $pat;
            $pat = $pat;
        }
        else 
        {
            $pat = $self->latin_pattern($pat);
        }
    }
}

sub latin_pattern
{
    my $self = shift;
    my $pat = shift;
    return $pat unless $pat;
    
    # We get (in Cicero) both auctio- @1 .nem and auctio- @1.nem
    my $non_alpha = '\\x00-\\x1f\\x21-\\x40\\x5b-\\x60\\x7b-\\xff';
    my $non_alpha_with_space = '\\x00-\\x40\\x5b-\\x60\\x7b-\\xff';
    # This code has been designed so that it will not disturb certain
    # Perl regexp constructs, such as char classes, and parens and | 
    # (alternation).  But many other types of input it may well mangle.
    
    # Turn every letter and every char class into a case insensitive
    # char class.
    $pat =~ s#([a-zA-Z]|\[[^\]]*\])#
                my $rep = $1;
                $rep =~ tr/\[\]//d;
                $rep =~ s/[ij]/ij/;
                $rep =~ s/[IJ]/IJ/;
                $rep =~ s/[uv]/uv/;
                $rep =~ s/[UV]/UV/;
                '['."\L$rep\E\U$rep\E".']'#gex; 
    
    print STDERR "Char classes: $pat\n" if $self->{debug};
                                
    # Add non-alphabetics
    # We have to allow spaces after hyphens and where there's a space
    # in the input pattern, because of e.g. page-breaks that intervene
    # like so: auctio- @1 .nem 
    $pat =~ 
        s/(\[[^\]]*\][*+?]?)(?!$)/$1(?:-\[$non_alpha_with_space\]\*|\[$non_alpha\]\*)/g;
    # spaces at the start + some lookbehind
    $pat =~ s/^\s+/(?<![A-Za-z])(?<!\-[\\x80-\\xff])(?<!\-[\\x80-\\xff][\\x80-\\xff])/g; 
    $pat =~ s/\s+$/(?![A-Za-z])/g;                     # spaces at the end
    $pat =~ s/(?<!^)(?<!-)\s+/\\s+\[$non_alpha_with_space\]\*/g;  # other spaces (not at start or end)
    $pat =~ s/\((?!\?)/(?:/g;                          # turn ( into (?: for speed
    return $pat;
}
                        

#####################################################################
#                                                                   #
# Subroutine to convert latinized greek to a useful search pattern. #
# Input is in Perseus format, output is TLG BETA code regexp.       #
#                                                                   #
#####################################################################

sub latin_to_beta 
{
    my $self = shift;
    $_ = shift;
    return $_ unless $_;
    
    die "Invalid letter $1 used in Perseus-style transliteration\n" if m/([wyjqv])/;
    die "Invalid letter c used in Perseus-style transliteration\n" if m/c(?!h)/;
    # This is now entirely case-insensitive (and ignorant of accent).
    # The business of having accents and breathings before caps
    # made it nearly impossible to do case- sensitive searches reliably, and
    # the best candidate regeps were an order of magnitude slower.
        
    # Sensitive to rough and smooth breathing ...
    s#\(#´#g;                                                       # protect parens
    s#\)#ª#g;

    s/\b([aeÍioÙu])/¨£$1/g;                  # mark where non-rough breathing goes
    s/(?<!\w)h/¨¨/gi;                        # mark where rough breathing goes

#       #s#\b([aeÍioÙu^]+)(?!\+)#(?:\\\)[\\/|+=]*$1|$1\\\))#gi;         # initial vowel(s), smooth
#
#       s#^h# h#; # If there's a rough breathing at the start of the pattern, then we assume it's the start of a word
#   s#(\s)([aeÍioÙu^]+)(?!\+)#$1(?:(?<!\\\([\\/|+=][\\/|+=])(?<!\\\([\\/|+=])(?<!\\\()$2(?!\\\())#gi;           # initial vowel(s), smooth
#       s#(\s)h([aeÍioÙu^]+)(?!\+)#$1(?:\\\([\\/|+=]*$2|$2\\\()#gi;             # initial vowel(s), rough breathing
#   s#\bh##; # Ignore breathings
    
    s/[eE]\^/H/g;                                           # eta
    s/[Í ]/H/g;                                             # ditto
    s/[tT]h/Q/g;                                            # theta
    s/x/C/g;                                                # xi
    s/[pP]h/F/g;                                            # phi
    s/[cC]h/X/g;                                            # chi
    s/[pP]s/Y/g;                                            # psi
    s/[oO]\^/W/g;                                           # omega
    s/[Ù‘]/W/g;                                             # ditto
        
    tr/a-z/A-Z/;                                            # upcap all other letters

    my $non_alpha = '\\x00-\\x1f\\x21-\\x40\\x5b-\\x5e\\x60\\x7b-\\xff';
    my $non_alpha_and_space = '\\x00-\\x40\\x5b-\\x5e\\x60\\x7b-\\xff';
    my $non_alpha_nor_asterisk = '\\x00-\\x1f\\x21-\\x29\\x2b-\\x40\\x5b-\\x5e\\x60\\x7b-\\xff';
    # The following allows trailing accents, hyphens, markup, etc. after letters, char classes and rough breathing
#s/(\[[^\]]*\][*+?]?|\(\?:(?:[^\\)]|\\\)|\\)*\)|[A-Z])/$1\[\\x00-\\x1f\\x21-\\x40\\x5b-\\x60\\x7b-\\xff\]\*/g;
#s/([^A-Z ]*[A-Z ][^A-Z ]*)/$1\[\\x00-\\x1f\\x21-\\x40\\x5b-\\x60\\x7b-\\xff\]\*/g;

# Put non-alpha after all chars.  Allow spaces where there is a hyphenation (page-break markup)

#     s/([^A-Z ]*[A-Z][^A-Z ]*)/$1\[$non_alpha\]\*/g;
      s/([^A-Z ]*[A-Z][^A-Z ]*)/$1(?:-\[$non_alpha_and_space\]\*|\[$non_alpha\]\*)/g;

# A space in the middle can gobble extra spaces for things like " @1 "
s/([^A-Z ]*[ ][^A-Z ]*)(?!$)/$1\[$non_alpha_and_space\]\*/g;
s/([^A-Z ]*[ ][^A-Z ]*)(?=$)/$1\[$non_alpha_nor_asterisk\]\*/g;
#s/(?<!^)\s+(?!$)/\[^A-Z\]/g;           # other spaces (not at start or end)
    # spaces at the start (the lookbehind tries to reject hyphenation fragments and
    # mid-word matches after accents, but we can't just reject on preceding accents,
    # since capitalized words do have accents preceding, and *must* not be rejected).
        s#^\s+#(?<![A-Z])(?<!\-[\\x80-\\xff])(?<![A-Z][)(\\/|+=])(?<![A-Z][)(\\/|+=][)(\\/|+=])(?<!\-[\\x80-\\xff][\\x80-\\xff])#g; 
#       s/\s+$/(?=[^A-Z])/g;            # spaces at the end -- this doesn't work -- previous glob backtracks off
#        s/\s+$/[ \\]}&\$\%"#\@>]/g;     # spaces at the end -- doesn't match
   
    #my $diacrits = '\/\\\\\=\+\?\!\)\(\|\'';
    
    # h looks ahead for a rough breathing somewhere in the following group
    # of vowels, or even before it as in the word (EA`N
    s#¨¨#(?=\\\(|[AEHIOWU/\\\\)=+?!|']+\\\()#gi;    
    s#¨£#(?!\\\(|[AEHIOWU/\\\\)=+?!|']+\\\()#g;     # opposite for smooth

    s/´(?!\?)/(?:/g;                                # turn ( into (?: for speed
    s/ª/)/g;                
    return $_;              
}

############################################################
#                                                          #
# As above, except without turning the greek into a regexp #
# (Used on input destined for the word list.)              #
#                                                          #
############################################################

sub simple_latin_to_beta 
{
    my $self = shift;
    $_ = shift;
    return quotemeta $_ if $self->{input_raw} or $self->{input_pure};
    if ($self->{input_beta})
    {
        tr/a-z/A-Z/;                                            # upcap all letters
        s#\\#/#g;
        $_ = quotemeta $_;
        s#\\\s+# #g;
        return $_;
    }
    
    tr/A-Z/a-z/;
    my $start;
    $start++ if s#^\s+##;
    
    s/\b([aeÍioÙu])/¨£$1/g;     # mark where non-rough breathing goes
    s#^h#¨¨#i;                  # protect h for rough breathing later
    
    s/[eE]\^/H/g;                                           # eta
    s/[Í ]/H/g;
    s/[tT]h/Q/g;                                            # theta
    s/x/C/g;                                                # xi
    s/[pP]h/F/g;                                            # phi
    s/[cC]h/X/g;                                            # chi
    s/[pP]s/Y/g;                                            # psi
    s/[oO]\^/W/g;                                           # omega
    s/[Ù‘]/W/g;
#   if (/h/) { $self->barf("I found an \`h\' I didn't understand in $_")};
    tr/a-z/A-Z/;                                            # upcap all other letters

    s#^# # if $start; # put the space back in front
    return $_;              
}

###############################################################
#                                                             #
# Method that actually does the brute-force searches.         #
# For an explanation of the approach using @ARGV, see p. 226  #
# of /Programming Perl/, 2nd edition.                         #
#                                                             #
# It takes a pattern and returns a hash of filenames, each    #
# pointing to an array containing the offsets of the matches. #
#                                                             #
###############################################################

sub pgrep 
{
    my $self = shift;
        
    chdir "$self->{cdrom_dir}" or 
        $self->barf ("cannot chdir to $self->{cdrom_dir} ($!)");
    print STDERR "\nCurrent dir: ",`pwd`, 
    "Prefix: $self->{file_prefix}\n\n" if $self->{debug};
    
    unless ($self->{filtered}) 
    {
        # In theory, the following code is platform independent for
        # achitectures (ie. Mac) that don't like unix-shell style globbing.
        opendir (INP_DIR, "$self->{cdrom_dir}") or 
            $self->barf ("Cannot open $self->{cdrom_dir} ($!)");
        @ARGV = grep {/$self->{file_prefix}.+$self->{txt_suffix}/i} readdir INP_DIR;
        closedir INP_DIR;
    }
    
    $self->barf ("I can't find any data files!") 
        unless @ARGV or $self->{req_auth_wk};
    local $/;
    undef $/;
    
    my $final_pass = $self->{numeric_context} ? 
          @{ $self->{pattern_list} } - 1
        : @{ $self->{pattern_list} } - $self->{min_matches_int};
    my ($buf, $i);
    $self->{buf} = \$buf;
    $self->read_blacklist if $self->{blacklist_file};
    $self->read_works_blacklist if $self->{blacklisted_works_file};

    if (@ARGV)
    {
        # Do the (full-file) search.  
        #print Data::Dumper->Dump(\@ARGV);
        while ($buf = <>) 
        { 
            # Search for the minimum necessary number of patterns
            for (   my $pass = 0; $pass <= $final_pass; $pass++  )
            {
                # Before each pass, make sure that the browser is still listening;
                # SIGPIPE does not work under MS Windows
                return if $Diogenes_Daemon::flag and not print ("\0");
                my $pattern = @{ $self->{pattern_list} }[$pass];
                # clear the last search
                undef $self->{seen}{$ARGV};
                push @{ $self->{seen}{$ARGV} }, pos $buf 
                    while ($buf =~ m#$pattern#g);
                if ($self->{seen}{$ARGV})
                {
                    my $auth_num = $ARGV;
                    $auth_num =~ tr/0-9//cds;
                    $self->parse_idt($auth_num);
                    $self->extract_hits($ARGV);
                }
            }
        } 
    }
    
    # Now search in any files that are to be read only in part.
    
    # Read in only the desired blocks from files for which only certain works 
    # were requested.
        
    my ($filename, $offset, $start_block, $end_block);
    foreach my $author (keys %{ $self->{req_auth_wk} }) 
    {
        # pad with leading zeroes 
        $filename = sprintf '%04d', $author;
        
        # parse .idt file
        my $real_num = $self->parse_idt($filename);
        
        $filename = $self->{file_prefix} . $filename;
                
        # open the .txt file 
        $filename .= $self->{txt_suffix};
        open INP, "$self->{cdrom_dir}$filename" or $self->barf("Couln't open $filename!");
        binmode INP;
                
        # loop through each requested work
        foreach my $work (sort keys %{ $self->{req_auth_wk}{$author} }) 
        {
            # get only those blocks of the file containing the work in question
            $start_block = $Diogenes::work_start_block{$self->{type}}{$real_num}{$work};
            $offset = $start_block << 13;
            seek INP, $offset, 0;
            my $next = $work;
            $next++;
            if (defined ($Diogenes::work_start_block{$self->{type}}{$author}{$next})) 
            {
                $end_block = $Diogenes::work_start_block{$self->{type}}{$author}{$next};
                read INP, $buf, (($end_block - $start_block + 1) << 13) or
                    $self->barf ("Couln't read from $filename");
            }
            else 
            {
                $buf = <INP>;
                $self->barf ("Couln't read the rest of $filename!") unless
                    defined $buf;
            }
            $self->{current_work} = $work;  
            
            # This does the search, storing the locations in %seen
            # Search for the minimum necessary number of patterns
            for (   my $pass = 0; $pass <= $final_pass; $pass++  )
            {
                return if $Diogenes_Daemon::flag and not print ("\0");
                my $pattern = @{ $self->{pattern_list} }[$pass];
                # clear the last search
                undef $self->{seen}{$author};
                
                push @{ $self->{seen}{$author} }, (pos $buf) 
                    while $buf =~ m#$pattern#g;
                $self->extract_hits($author);
            }
        }
        close INP or $self->barf("Couln't close $filename!");
    }
    
    return 1;
}

##################################################################
#                                                                #
# Method to remove from @ARGV any files that match the blacklist #
# of files that we never want to search through.                 #
#                                                                #
##################################################################

sub read_blacklist
{
    my $self = shift;
    my $bl;
    open BL, "<$self->{blacklist_file}" or 
        die "Couldn't open blacklist file: $self->{blacklist_file}: $!\n";
    {
        local $/;
        undef $/;
        $bl = <BL>;
    }
    print STDERR "Files originally in ARGV: ".scalar @ARGV."\n" if $self->{debug};
    my @files;
    $self->{blacklisted_files} = 0;
    foreach my $file (@ARGV)
    {
        $file =~ m/($self->{file_prefix}\d\d\d\d)/;
        my $pat  = $1;
        if ($bl =~ m/$pat/i)
        {
            print STDERR "Removing blacklisted file: $file\n" if $self->{debug};
            $self->{blacklisted_files}++;
        }
        else
        {
            push @files, $file;
        }
    }
    @ARGV = ();
    @ARGV = @files;
    print STDERR "Files remaining in ARGV: ".scalar @ARGV."\n" if $self->{debug};
}

sub read_works_blacklist
{
    my $self = shift;
    open BL, "<$self->{blacklisted_works_file}" or 
        die "Couldn't open blacklisted works file: $self->{blacklisted_works_file}: $!\n";
    {
        local $/;
        $/="\n";
        
	while (my $entry = <BL>)
	{
            chomp $entry;
            next if $entry =~ m/^\s*$/;
            next if $entry =~ m/^#/;
            my ($auth, @works) = split ' ', $entry;
            die "Bad blacklisted works auth ($self->{blacklisted_works_file}): $auth\n" 
                unless $auth =~ m/^\D\D\D\d+$/;
            my ($type, $auth_num) = $auth =~ m/^(\D\D\D)(\d+)$/;
            $type = lc $type;             
            $auth_num = sprintf '%04d', $auth_num;
            
            for (@works)
            {
                die "Bad blacklisted work ($self->{blacklisted_works_file}): $_\n" 
                    unless $_ =~ m/^\d+$/;
                $_ = sprintf '%03d', $_;
                warn "Blacklisting $type$auth_num: $_\n" if $self->{debug};
                $self->{blacklisted_works}{$type}{$auth_num}{$_} = 1;
            }
        }
    }
    $self->{blacklisted_hits} = 0;
    close BL or 
        die "Couldn't close blacklisted works file: $self->{blacklist_file}: $!\n";
}

######################################################################
#                                                                    #
# Method to extract the author, work and label info from an idt file #
# -- the info goes into globals %author, %work and %level_label,     #
# keyed by type of search -- may be reused in subsequent searches.   #
#                                                                    #
######################################################################

sub parse_idt 
{
    my ($self, $au_num) = @_;
    my ($lev, $str, $auth_num, $author_name, $work_num, $work_name, $old_work_num);
    my ($sub_work_abbr, $sub_work_name, $code, $desc_lev, $start_block, $first_byte);
    my ($subsection, $current_block, $block);
    $current_block = 0;
        
    $self->{current_lang} = $Diogenes::lang{$self->{type}}{$au_num};
    $self->{current_lang} = 'l' if $self->{type} eq 'bib';
    $self->{current_lang} = 'g' if $self->{type} eq 'cop';
        
    # Don't read again (except for CIV texts, where $au_num is not a number)
    return $au_num if exists $Diogenes::author{$self->{type}}{$au_num}; 
        
    # This file must be read via unbuffered system I/O if it is to be interwoven
    # between successive reads of .txt files from <ARGV>.  Otherwise this flushes 
    # the .txt files out of the I/O cache and hugely increases search times.
        
    # We therefore do not want to overwrite buf, which may now contain the
    # contents of the corresponding .txt file, so we use idt_buf
    # instead.
    my $file = $self->{file_prefix} . $au_num . $self->{idt_suffix};
    my $i; 
    my $idt_buf = '';
        
    sysopen IDT, $self->{cdrom_dir}.$file, 0 or 
        $self->barf("Could not open $self->{cdrom_dir}$file - $!");
    binmode IDT;
        
    while (my $len = sysread IDT, $idt_buf, 8192, length $idt_buf) 
    {
        if (!defined $len) 
        {
            next if $! =~ /^Interrupted/;
            $self->barf ("System read error on $self->{cdrom_dir}.$file: $!\n");
        }
    }
    my $end = length $idt_buf;
    close IDT or $self->barf("Could not close $file");
    
    undef $old_work_num;
    for ($i = 0; ($i < $end); $i++) 
    {
        $code = ord (substr ($idt_buf, $i, 1));
        
        last if ($code == 0);           # eof
        
        if ($code == 1 or $code == 2) 
        {       # new author or work
            $subsection = 0;
            undef %{ $self->{level} };
            $i += 2;
            $first_byte = ord (substr $idt_buf, ++$i, 1) << 8;
            $start_block = $first_byte + ord (substr $idt_buf, ++$i, 1);
            
            if (ord (substr ($idt_buf, ++$i, 1)) == hex ("ef")) 
            {
                $lev = (ord (substr ($idt_buf, ++$i, 1))) & MASK;
                $str = get_ascii_string( \$idt_buf, \$i );
                if ($lev == 0) 
                {
                    $auth_num = $str;
                    $Diogenes::last_work{$self->{type}}{$auth_num} = 0;
                    # The misc files (CIV000x on the LAT disk) have an
                    # alphabetic string here, rather than the number, so now
                    # be careful not to assume that $auth_num is a number.
                    if ((ord (substr ($idt_buf, ++$i, 1)) == hex ("10")) &&
                        ((ord (substr ($idt_buf, ++$i, 1))) == hex ("00"))) 
                    {
                        $i++;
                        $author_name = get_pascal_string( \$idt_buf, \$i );
                        $Diogenes::author{$self->{type}}{$auth_num} = $author_name;
                    } 
                    else 
                    { 
                        $self->barf("Author number apparently was not followed by".
                                                " author name in idt file $file");
                    }
                }
                elsif ($lev == 1) 
                {
                    $work_num = $str;
                    $Diogenes::last_work{$self->{type}}{$auth_num} = $work_num 
                        if $work_num > $Diogenes::last_work{$self->{type}}{$auth_num};
                    if      ((ord (substr ($idt_buf, ++$i, 1))  == hex ("10")) &&
                             ((ord (substr ($idt_buf, ++$i, 1))) == hex ("01"))) 
                    {
                        $i++;
                        $work_name = get_pascal_string( \$idt_buf, \$i );
                        $Diogenes::work{$self->{type}}{$auth_num}{$work_num} = $work_name; 
                        
                        $Diogenes::work_start_block{$self->{type}}
                        {$auth_num}{$work_num} = $start_block;
                        
                        # Get the level labels
                        if ($self->{type} eq 'misc' and defined $old_work_num)
                        {
                            # For CIV texts, only level labels that change are listed
                            # explicitly, so we must preinitialize them.
                            $Diogenes::level_label{$self->{type}}
                            {$auth_num}{$work_num} =
                            { % {$Diogenes::level_label{$self->{type}}
                                 {$auth_num}{$old_work_num}} };
                        }
                        while (ord (substr ($idt_buf, ++$i, 1)) == hex("11")) 
                        {
                            $desc_lev = ord (substr ($idt_buf, ++$i, 1));
                            $i++;
                            $Diogenes::level_label{$self->{type}}
                            {$auth_num}{$work_num}{$desc_lev} =
                                get_pascal_string( \$idt_buf, \$i ); 
                        }
                        $i--;           # went one byte too far
                        $old_work_num = $work_num;
                    } 
                    else 
                    { 
                        $self->barf("Work number apparently was not followed by work 
                                                name in idt file $file")
                    }
                    
                    if ($self->{documentary})
                    {
                        $Diogenes::level_label{$self->{type}}
                        {$auth_num}{$work_num}{5} =
                            delete $Diogenes::level_label{$self->{type}}
                        {$auth_num}{$work_num}{0};
                    }
                } 
                elsif ($lev == 2) 
                {       # Trap this for now
                    $self->barf ("Hey! I found a sub-work level in idt file $file");
                    
                    # The real code should look something like this:        
                    $sub_work_abbr = $str;
                    if (ord (substr ($idt_buf, ++$i, 2)) == hex '1002') 
                    {
                        $i++;
                        $sub_work_name = get_pascal_string( \$idt_buf, \$i );
                        $Diogenes::sub_works{$self->{type}}{$auth_num}{$work_num}{$sub_work_abbr} = $sub_work_name; 
                    } 
                    else 
                    { 
                        $self->barf(
"Sub-work number apparently was not followed by sub-work name in idt file $file")
                    }
                }
                else 
                {
                    $self->barf (
                        "I don't understand level $lev after \0xef in idt file $file.")
                }
            }
            else 
            {
                $self->barf ("I see a new author or a new work in ".
                             "idt file $file, but it is not followed after 5 ".
                             "bytes by \\0xef.");
            }
        } 
        elsif ($code == 3)
        {
            # Get the starting blocks of each top-level subsection    
            $block = (ord (substr $idt_buf, ++$i, 1) << 8) + ord (substr $idt_buf, ++$i, 1);
            die "Error.  New section not followed by beginning ID" 
                unless ord (substr $idt_buf, ++$i, 1) == 8;
            $i++;
            while ((my $sub_code = ord (substr ($idt_buf, $i, 1))) >> 7)
            {
                parse_bookmark($self, \$idt_buf, \$i, $sub_code);
                $i++;
            }
            $i--;           # went one byte too far
            my $top_level = (sort {$b <=> $a} keys %{ $self->{level} })[0];
            $Diogenes::top_levels{$self->{type}}{$auth_num}{$work_num}[$subsection] = 
                [$self->{level}{$top_level}, $block];
            $subsection++;
            
            # NB. This resynchronization is necessary for the TLG, not the PHI
            $current_block = $block;
        }
        elsif ($code == 10)
        {
            $i++;
            while ((my $sub_code = ord (substr ($idt_buf, $i, 1))) >> 7)
            {
                parse_bookmark($self, \$idt_buf, \$i, $sub_code);
                $i++;
            }
            $i--;           # went one byte too far
            $Diogenes::last_citation{$self->{type}}{$auth_num}{$work_num}{$current_block} 
                = {%{ $self->{level} }};
            $current_block++;
        }
        elsif ($code == 11 or $code == 13) 
        {   # "Exceptions" -- which we ignore
            $i += 2;
        }
        
        # do nothing in the other cases
        
    } # end of for loop
    
#       use Data::Dumper;
#       print Dumper $Diogenes::top_levels{$self->{type}}{$auth_num};
#       print Dumper $Diogenes::last_citation{$self->{type}}{$auth_num};
#       print "$auth_num => $current_block \n"
#        if ($current_block +1 << 13) != -s "$self->{cdrom_dir}$self->{file_prefix}$auth_num.txt";
    return $auth_num;
}



####################################################################
#                                                                  #
# Subroutine to get a string from $$buf until a \xff is hit,       #
# starting at $i.                                                  #
#                                                                  #
####################################################################

sub get_ascii_string 
{
    my ($buf, $i) = @_;
    my $char;
    my $string = "";
    until ((ord ($char = substr ($$buf, ++$$i, 1))) == hex("ff"))
    {
        $string .= chr ((ord $char) & MASK);
    }
    return $string
}


###############################################################
#                                                             #
# Subroutine to extract pascal-style strings with the         #
# length byte first (used for list.bin files).                #
#                                                             #
###############################################################

sub get_pascal_string 
{
    my ($buf, $i) = @_;
    my $str = "";
    my $len = ord (substr ($$buf, $$i, 1));
    for ($$i++; $len > 0; $$i++, $len--) 
    {
        $str .= chr (ord (substr ($$buf, $$i, 1)));
    }
    $$i--;  # went one byte too far
    return $str;
}

sub read_tlg_biblio
{
    # Only reads in file, too massive to parse now
    my $self = shift;
    return if $Diogenes::bibliography;
    local $/;
    undef $/;
    my $filename = "$self->{cdrom_dir}doccan2.txt";
    my $Filename = "$self->{cdrom_dir}DOCCAN2.TXT";
    open BIB, $filename or open BIB, $Filename or die "Couldn't open $filename: $!";
    binmode BIB;
    $Diogenes::bibliography = <BIB>;
    close BIB, $filename or die "Couldn't close $filename: $!";
    $self->{print_bib_info} = 1;
}

sub read_phi_biblio
{
    # Read and parses file
    my $self = shift;
    my $filename = "$self->{cdrom_dir}$self->{file_prefix}9999.txt";
    if (-e "$filename")
    {
        local undef $/;
        open PHI_BIB, $filename or die "Couldn't open $filename: $!";
        binmode PHI_BIB;
        my $canon = <PHI_BIB>;
        while ($canon =~ m/([^{]+)\{\`?(\d\d\d\d)\.(\d\d\d)\}/g)
        {
            my ($info, $auth, $work) = ($1, $2, $3);
            $info =~ s/[\x80-\xff][\@\s\x80-\xff]*/\n/g;
            $info =~ s/\n+/\n/g;
            $info =~ s/^[\n\s]+//;
            $info .= ' ('.$auth.': '.$work.')';
            $info .="\n" unless $info =~ m/\n$/;
            $self->{phi_biblio}{$auth}{$work} = $info;
        }
        close PHI_BIB, $filename or die "Couldn't close $filename: $!";
        $self->{print_bib_info} = 1;
    }
    else
    {
        print STDERR "PHI Canon ($filename) not found!" if $self->{debug};
    }
}

sub get_biblio_info
{
    my ($self, $type, $auth, $work) = @_;
    
    return $self->get_tlg_biblio_info($auth, $work) if $type =~ m/tlg/i;
    if (exists $self->{phi_biblio}{$auth}{$work})
    {
	return $self->{phi_biblio}{$auth}{$work} if $type =~ m/phi/i ;
    }
    return ' ('.$auth.': '.$work.')';
}


sub get_tlg_biblio_info
{
    # Looks for a single work, memoizes result
    my ($self, $auth, $work) = @_;
    return undef unless $Diogenes::bibliography;
    return $self->{biblio_details}{$auth}{$work}    
    if exists $self->{biblio_details}{$auth}{$work};
    
    my ($info) = $Diogenes::bibliography =~ 
        m/key $auth $work (.+?)[\x90-\xff]*key/;
     return $Diogenes::work{$self->{type}}{$self->{auth_num}}{$self->{work_num}}
         unless $info;
    my %data;
    my @fields = qw(wrk tit edr pla pub pyr ryr ser pag);
    foreach my $field (@fields)
    {
        while 
            ($info =~ 
             m/[\x80-\x8f]?$field ([\x00-\x7f]*(?:[\x80-\x8f]    [\x00-\x7f]+)*)?\s?[\x80-\x8f]?/g)
            
        {
            my $datum = $1 || '';
            $datum =~ s/\s*$//;                     # trailing spaces
            $datum =~ s/[\x80-\x8f]    //g; # long lines
            $data{$field} .= $data{$field} ? ", $datum" : $datum;
        }
    }
    $self->{biblio_details}{$auth}{$work} = 
        join '', (
            "$Diogenes::author{$self->{type}}{$self->{auth_num}}, ",
            ($data{wrk}) ? "$data{wrk}\&" : '' ,
            ' ('.$self->{auth_num}.': '.$self->{work_num}.')',
            ($data{tit}) ? "\n\"$data{tit}\&\"" : '' ,
            ($data{edr}) ? ", Ed. $data{edr}\&" : '' , 
            ($data{pla}) ? "\n$data{pla}\&" : '' ,
            ($data{pub}) ? ": $data{pub}\&" : '' ,
            ($data{pyr}) ? ", $data{pyr}\&" : '' ,
            ($data{ryr}) ? ", Repr. $data{ryr}\&" : '' ,
            ($data{ser}) ? "; $data{ser}\&" : '' ,
#                       ($data{pag}) ? ", $data{pag}\&" : '',
            '.');
    return $self->{biblio_details}{$auth}{$work};
}

##################################################################################
#                                                                                #
# Subroutine to seek to the position of each hit in a search and for each one to #
# extract the location info and surrounding context.                             #
#                                                                                #
##################################################################################

sub extract_hits 
{
    my ($self, $auth) = @_;
    my ($match, $block_start, $location);
    my ($code, $start, $end, $lines, $result, $this_work, $pos);
    my $current_block_start = -1;
    my $buf = $self->{buf};
    
    # load up the author, work and label info for that file (from the
    # corresponding .idt file, but only for full-file searches -- word 
    # list searches and partial files will have parsed the idt file aleady, 
    # in order to see what blocks the work in question lies in.
    
    # Get context regexps for the current language
    my $numeric = $1 if $self->{context} =~ m/(\d+)/;
    my $context = 
        $Diogenes::context{$self->{current_lang}}{$self->{context}} 
        || $numeric;

    my $overflow  = $self->{overflow}->{$self->{context}} || $self->{max_context};

    # This is used to reject candidates for sentence, etc. ending; matches against: (..X..)
    my $reject = ($self->{current_lang} eq 'g') ?
        qr /^\.\ |^.\.\.|^[ &][A-Za-z]|^[a-z][a-z]\.|^.\$|^..@\d|^...[&\$]|^..._|^..\.[ \]]\d/ :
        qr /^\.\ |^.\.\.|^\ [A-Za-z]|^fr\.|^cf\.|^eg\.|^.\$|^..@\d|^...[&\$]|^..._|^..\.[ \]]\d|^[A-Z]|^.[A-Z]/;
        
    my ($offset, $last_offset, $parsed_block) = (-1, -1, 0);
    HIT: foreach $match ( 0 .. $#{ $self->{seen}{$auth} } ) 
    {
        # The blocks containing the work in
        # question have been read into memory, so all we need to do
        # is to start at the beginning of the correct block
        $last_offset = $offset;
        $offset = $self->{seen}{$auth}[$match];
        my $buf_start  = (($offset >> 13) << 13);
        
        # Optimize case where one hit comes close after the previous,
        # so as not to go back to parse once again unneccessarily from
        # the beginning of the same block.  But watch out for cases
        # where a failed multiple match (next HIT) has skipped that
        # parsing
        if ($parsed_block and $last_offset != -1 and 
            ($offset - $last_offset < $offset - $buf_start))
        {
            $buf_start = $last_offset;
        }
        $parsed_block = 0; # set flag false
        
        if ($self->{check_word_stats})
        {
            # We have to scan for the location of this hit in the case of
            # indexed searches, even when it will not be displayed, in order 
            # to maintain proper statistics for the number of hits per work. 
            for (my $i = $buf_start; $i < $offset; $i++ ) 
            {
                # parse all of the data in this block from its beginning to our match
                $code = ord (substr ($$buf, $i, 1));
                next unless ($code >> 7); # high bit set
                $self->parse_non_ascii ($buf, \$i);             
            }
            $parsed_block = 1;
            
            print STDERR "$self->{work_num} ... $self->{current_work}\n" if
                $self->{debug};
            # for word-list searches, discard any hits that are not in the right
            # work (i.e. there might be other hits in this set of blocks too)
            next HIT if ($self->{current_work} and 
                         ($self->{work_num}) != $self->{current_work});  
            
        }
        
        $start = $offset - 2;
                
        # Get context block
        if ($self->{numeric_context}) 
        {
            # Get a number of lines of context before the match -- the concept of
            # `line' here is very unsophisticated.
            for ($lines = 0; $lines <= $context and 
                 ($start > 0); $start--) 
            {
                $lines++ if (((ord (substr ($$buf, $start, 1))) >> 7) and not
                             (ord (substr ($$buf, $start - 1, 1)) >> 7)); 
            }
            $start+=2;
        }
        else
        {       
            # Find the start of the word pattern -- our pattern might have 
            # punctuation inside, or may simply have picked some up along the way.
            for ($start--; $start > 0; $start--)
            {
                last if substr ($$buf, $start, 2) =~ /[a-zA-Z)(=\\\/+][\s.,;:]/;
            }
            # Get a regexp-delimited context
            for ($lines = 0; $start > 0; $start--)
            {
                # Lookahead so as to avoid ?_, @1, $., .&, Q. Horatius usw.
                last if substr ($$buf, $start, 1) =~ /$context/
                    and not substr ($$buf, $start - 2, 5) =~ $reject;
                # Failsafe
                $lines++ if (((ord (substr ($$buf, $start, 1))) >> 7) and not
                             (ord (substr ($$buf, $start - 1, 1)) >> 7)); 
                last if $lines >= $overflow; 
            }
            # Try to eliminate stray chars and wasteful whitespace
            #while (substr ($$buf, ++$start, 1) =~ /[\s\d'"@}\])&\$\x80-\xff]/) {};
            while (substr ($$buf, ++$start, 1) =~ /[\s\d'"@}\])\x80-\xff]/) {};
        }
        
        next HIT if $self->{already_reported}{$auth}{$start} and 
            not $self->{check_word_stats};
        
        if ($self->{numeric_context}) 
        {
            # Get lines of context after the match.
            for ($end = $offset, $lines = 0; ($lines <= $context) and 
                 ($end < length $$buf ) ; $end++) 
            {
                $lines++ if (((ord (substr ($$buf, $end, 1))) >> 7) and not 
                             (ord (substr ($$buf, $end + 1, 1)) >> 7)); 
            }
            $end-=2;
        } 
        else
        {
            # Get a regexp-delimited context
            for ($end = $offset, $lines = 0; $end < length $$buf; $end++)
            {
                # Lookahead so as to avoid ?_, @1, $. usw.
                last if substr ($$buf, $end, 1) =~ /$context/
                    and not substr ($$buf, $end - 2, 5) =~ $reject;
                # Failsafe
                $lines++ if (((ord (substr ($$buf, $end, 1))) >> 7) and not
                             (ord (substr ($$buf, $end + 1, 1)) >> 7)); 
                last if $lines >= $overflow; 
            }
            $end++; # Take one more
        }
        
        $result = substr ($$buf, $start, ($end - $start));
        
        # We use ~hit~...~ (and later ˇˇ) as temp placeholders for \hit{...},
        # because "\" is special in both BETA code and TeX, as are {}; 
        # ˇˇ is not used in BETA (except as a binary stop code), nor in utf-8.
        
        # We want to highlight all matching patterns, and yet accept only those
        # passages where there are matches across a mimimum number of distinct
        # patterns from the list
        my %matches = ();
        if ($self->{output_format} eq 'beta' or not $self->{highlight})
        {
            my $n = 0;
            map {$matches{$n}++ if $result =~ /$_/; $n++;}(@{ $self->{pattern_list} });
            my $matching_sets = values %matches;
            print STDERR "+ $result\n" if $self->{debug};
            print STDERR "+ $matching_sets: $auth, $offset\n" if $self->{debug};
            die "ERROR: Disappearing Match!\n" unless $matching_sets;
            next HIT unless $matching_sets >= $self->{min_matches_int};
            next HIT if $self->{reject_pattern} and $result =~ m/$self->{reject_pattern}/;
        }
        else
        {
            my $n = 0;
            map     {$result =~ s#(~hit~[^~]*~)|((?:\*[)(/\\\\=+|']*)?$_[)(/\\\\=+|']*)#
                                                                        if ($2) {$matches{$n}++; '~hit~'.$2.'~'}
                                                                        else    {$1}
                                                                        #ge;
                     $n++;}
                (@{ $self->{pattern_list} });
            my $matching_sets = values %matches;
            print STDERR "+ $result\n" if $self->{debug};
#                       print STDERR "+ ".$self->{pattern_list}[0]."\n" if $self->{debug};
            print STDERR "+ $matching_sets: $auth, $offset\n" if $self->{debug};
            die "ERROR: Disappearing Match!\n" unless $matching_sets;
            next HIT unless $matching_sets >= $self->{min_matches_int};
            next HIT if $self->{reject_pattern} and $result =~ m/$self->{reject_pattern}/;
        }
                
        if ($self->{check_word_stats})
        {
            # keep a running total of hits
            $self->{hits_hash}{$self->{auth_num}}
            {$self->{work_num}}{$self->{word_key}}++;
            print STDERR $self->{auth_num}, "; ", 
            $self->{work_num}, "; ", 
            $self->{word_key},   "; ", 
            $self->{hits_hash}{$self->{auth_num}}{$self->{work_num}}
            {$self->{word_key}}, 
            "\n" if $self->{debug};
            next HIT if $self->{already_reported}{$auth}{$start};
        }
        else
        {
            # Only now do we belatedly find the location for searches that
            # ignore statistics (ie. all but indexed searches of the TLG), since
            # we are sure we want to output this block.
            for (my $i = $buf_start; $i < $offset; $i++ ) 
            {
                # parse all of the data in this block from its beginning to our match
                $code = ord (substr ($$buf, $i, 1));
                next unless ($code >> 7); # high bit set
                $self->parse_non_ascii ($buf, \$i);             
            }
        }
        # Set flag to true, since we have passed by all of the next
        # HIT statements, and we have definitely parsed the location
        # info for this hit, meaning we can use it as the basis for
        # the location info for the next hit in this block
        $parsed_block = 1;
        
        $self->{hits}++;
            
        if (exists $self->{blacklisted_works} 
            and $self->{blacklisted_works}{$self->{file_prefix}}{$self->{auth_num}}{$self->{work_num}})
        {
            warn "Warning: supressing hit in blacklisted work ($self->{auth_num}: $self->{work_num})\n";
            $self->{blacklisted_hits}++;
            next HIT;
        }

        # Add spaces to start of line for proper indent
        my $spaces = -1;
        for (my $pre_start = $start; not (ord (substr ($$buf, $pre_start--, 1)) >> 7); 
             $spaces++)     {}
        $result = ' ' x $spaces . $result;
        
        $location = "\n\&";
        # extract and print the author, work and location of the match
        #print STDERR ">>".$self->{type}.$self->{auth_num}."||\n";

        $this_work = "$Diogenes::author{$self->{type}}{$self->{auth_num}}, ";
        $this_work .= 
            "$Diogenes::work{$self->{type}}{$self->{auth_num}}{$self->{work_num}} ";
        $location .= ($self->{print_bib_info} and not 
                      $self->{bib_info_printed}{$self->{auth_num}}{$self->{work_num}})
            ? $self->get_biblio_info($self->{type}, $self->{auth_num}, $self->{work_num})
            : $this_work;
        $self->{bib_info_printed}{$self->{auth_num}}{$self->{work_num}} = 'yes'
            if $self->{print_bib_info}; 
        
        $location .="\&\n";
                
        foreach (reverse sort keys %{ $self->{level} }) 
        {
            if 
                ($Diogenes::level_label{$self->{type}}{$self->{auth_num}}{$self->{work_num}}{$_})
            {
                $location .=
                    "$Diogenes::level_label{$self->{type}}{$self->{auth_num}}{$self->{work_num}}{$_}".
                    " $self->{level}{$_}, ";
            }
            elsif ($self->{level}{$_} ne '1') 
            {       # The Theognis exception & ddp
                $location .= "$self->{level}{$_}, ";
            }
        }
        chop ($location); chop ($location);
        if ($self->{special_note}) 
        {
            $location .= "\nNB. $self->{special_note}";
            undef $self->{special_note};
        }

        $location .= "\n\n";
        if ($Diogenes::cgi_flag and $self->{cgi_buttons})
        {
            my $browse_start = $start;
            if (ref $self eq 'Diogenes_indexed')
            {
                # Indexed searches do not read the whole file into the buffer; only
                # the blocks containing the current work
                $browse_start += $Diogenes::work_start_block{$self->{type}}{$self->{auth_num}}{$self->{work_num}} << 13;
            }
            $result .= "\n~~~$self->{auth_num}~~~$self->{work_num}~~~$browse_start~~~\n";
        }
        else
        {
            $result .= "\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
        }
        my $base = ($self->{current_lang} eq 'g')
            ? '$'
            : '&';
        my $output = '& ' . $location . $base . $result;
        
        $self->print_output(\$output);
        
        $self->{already_reported}{$auth}{$start}++;
        
    } # end of foreach.
} # end of sub extract_hits.

###################################################################
#                                                                 #
# Method to get the author and work numbers and to update the     #
# bookmarks in %level while reading from a .txt file block.       #
#                                                                 #
###################################################################

sub parse_non_ascii 
{
    my ($auth_abbr, $work_abbr, $lev, $str);
    my ($new_auth_num, $new_work_num, $code);
    my ($self, $buf, $i) = @_;
    undef $self->{special_note};
    
    # Parse all of the non-ascii data in this block
    while (($code = ord (substr ($$buf, $$i, 1))) >> 7)
    {
        ##printf "Code: %x \n", $code if $self->{debug};
        # Ok. This is legacy code from when I was trying to understand the
        # file formats.  At some stage this sub should be folded in with 
        # parse_bookmarks, so that level `e' ( = 6 ) is handled just like       
        # the rest.  At the moment this code seems to work, so we'll leave it.
        if ($code == hex 'e0')
        {
            $self->{work_num}++ if ord substr ($$buf, ++$$i, 1) == hex '81';
        }
        elsif ($code > hex 'e0' and $code < hex 'e8')
        {
            $self->{work_num} = $code & RMASK if ord substr ($$buf, ++$$i, 1) == hex '81';
        }
        
        # Do we need at some point to handle e8 < $code < ef ??
        
        elsif ($code == hex 'ef') 
        { 
            $lev = (ord substr ($$buf, ++$$i, 1)) & MASK;
            $str = get_ascii_string( $buf, $i );
            if ($str eq '')
            {       # do nothing
            }
            elsif ($lev == 0) 
            {
                $new_auth_num = $str;
                if ($new_auth_num ne $self->{auth_num}) 
                {
                    undef %{ $self->{level} };
                    $self->{auth_num} = $new_auth_num;
                }
            } 
            elsif ($lev == 1) 
            {
                $new_work_num = $str;
                if ($new_work_num ne $self->{work_num}) 
                {
                    undef %{ $self->{level} };
                    $self->{work_num} = $new_work_num;
                }
                
            } 
            elsif ($lev == 2) 
            {
                $work_abbr = $str;      #  Evidently useless info
            }               
            elsif ($lev == 3) 
            {
                $auth_abbr = $str;      #  Ditto
            }
            elsif ($lev == hex '6c')
            {
                # Papyrus provenance
                
                # There are sometimes non-printable chars in here ...
                # and get rid of &'s, since these never switch back to Greek
                $str =~ s/[\x00-\x1f\x7f]//g;
                $str =~ s/\&\d*//g;
                $self->{special_note} = '';
                $self->{special_note} .= "Loc: $str" if $str;
            }
            elsif ($lev == hex '64')
            {
                # Papyrus date
                $str =~ s/[\x00-\x1f\x7f]//g;
                $str =~ s/\&\d*//g;
                $self->{special_note} .= '; ' if $self->{special_note};
                $self->{special_note} .= "Date: $str" if $str;
            }
            elsif ($lev == hex '74')
            {
                # Papyrus what??
                
                $str =~ s/[\x00-\x1f\x7f]//g;
                $str =~ s/\&\d*//g;
                $self->{special_note} .= " $str" if $str;
            }
            elsif ($lev == hex '72')
            {
                # Papyrus reprintings
                
                $str =~ s/[\x00-\x1f\x7f]//g;
                $str =~ s/\&\d*//g;
                $self->{special_note} .= '; ' if $self->{special_note};
                $self->{special_note} .= "Repr: $str" if $str;
            }
            
            # elsif ($lev == 99) {$self->{special_note} = $str}
            # else die("What is level $lev after 0xef? ($i)")
            # Some newer PHI disks encode additional info here, such as the dates
            # of Cicero's letters.
            
            else 
            {
                # For PHI disks, the info is included in the text itself 
                # on newer disks -- we would like to know
                # what distinguishes source references, from, say, the dates of
                # Cicero's letters.  This must be documented somewhere
                $self->{special_note} .= '; ' if $self->{special_note};
                $self->{special_note} .= $str;
            }
        }
        
        # This "junk" is e.g. the citation codes for Plato!  
        ##elsif ($code == hex '9f' or $code == hex '8f') 
        ##{     # What does this mean ?
        ##      my $junk = get_ascii_string( $buf, $i );
        ##}    
        
        elsif ($code == hex 'fe') 
        {
            # End of block: this should only be encountered when browsing past 
            # the end of a block -- so we skip over end of block (nulls)
            while (ord (substr ($$buf, ++$$i, 1)) == hex("00"))
            { 
                #do nothing, except error check
                warn ("Went beyond end of the buffer!") if $$i > length $$buf;
                return;
            }
            $$i--; # went one too far
        }
        elsif ($code == hex 'f0')
        {
            # End of file
            warn "Hit end of file marker!";
            return;
        }
        else 
        {
            # none of the above, so update bookmark 
            parse_bookmark ($self, $buf, $i, $code);
        }
        
        $$i++; # peek ahead to next $code
    }
    $$i--; # went one too far -- end on end of block (\xff, usually)
    return;
}

###################################################################################
#                                                                                 #
# Subroutine to parse a non-ascii bookmark that sets or increments one of the     #
# counters that keep track of what line, chapter, book, etc. we are currently at. #
#                                                                                 #
###################################################################################

sub parse_bookmark 
{       
    # adjust counters
    my ($self, $buf, $i, $code) = @_;
    my ($left, $right, $num, $char, $top_byte, $low_byte, $str);
    my ($letter, $j);
    
    # left nybble: usually gives the level of the counter being modified.
    $left = ($code & LMASK) >> 4;   
    
    # right nybble: dictates the form of the upcoming data (when > 8).
    $right = $code & RMASK; 

    # 7 is EOB, EOF, or end of string, and should not be encountered here.  
    # 6 (apart from 0xef as end of string, which is handled elsewhere) seems
    # to have been used in newer PHI disks ( >v.5.3 -- eg. Ennius).  The 
    # earlier disks don't have this info, and it doesn't add much, so
    # we might consider throwing it away (see below, where is is used).
    # 5 is the top level counter for the DDP disks.
    
    if ($left == 7) 
    {       
        # These bytes are found in some versions of the PHI disk (eg. Phaedrus)
        # God knows what they mean.  phi2ltx says they mark the beginning and
        # end of an "exception".
        return if $code == hex('f8') or $code == hex('f9');
        
        die ("I don't understand what to do with level ".
             "$left (right = $right, code = ". (sprintf "%lx", $code) . 
             "; offset ". (sprintf "%lx", $$i) ); 
    }
    
    if ($left == 6) 
    {
        # This is redundant info (?), since earlier versions of the
        # disks apparently omit it and do just fine.  
        # This are the a -- z levels: encoded ascii!!
        
        # Commented out since the DDP encodes something wierd here,
        # and it is not synonymous with the other levels info
        
        #my %letters = (        z => 0, y => 1, x => 2, w => 3, 
        #                               v => 4, u => 5, t => 6, s => 7 );
        # Let's hope that's enough!
        
        #$letter = chr (ord (substr ($$buf, ++$$i, 1)) & MASK); 
        #$left = $letters{$letter} || 0;
        
        # Throw this info away
        $$i++;
        $$i++           if $right == 8 or $right == 10;
        $$i += 2        if $right == 9 or $right == 11 or $right == 13;
        $$i += 3        if $right == 12;
        my $junk = get_ascii_string( $buf, $i ) if $right == 10 
            or $right == 13 or $right == 15;
        die "I don't understand a right nybble value of 14" if $right == 14;
        return;
    }
    
    # NB. All lower levels go to one when an upper one changes.
    # In some texts (like Catullus on the older PHI disks), 
    # lower level counters are assumed to go to one, rather than
    # to disappear when higher levels change.  
    # This is also true for the DDP disk!
    $left and map $self->{level}{$_} = 1, (0 .. ($left - 1));
    
    # The usual case: increment the counter specified by the left nybble.
    if ($right == 0) 
    {       
        # Also incr. non-digits: 1e1 goes to 1e2, 1b goes to 1c, etc.
        $self->{level}{$left} = '' unless exists $self->{level}{$left};
        $self->{level}{$left} =~ s/([a-zA-Z]*[0-9]*)$/my $rep = $1 || 0;
                                                                                                                $rep++; $rep/ex; 
        ##print "))".$left.": ".$self->{level}{$left}."\n" if $self->{debug};
    }
    # Otherwise, set counter to value whose type is given in right nybble.
    elsif (($right > 0) and ($right < 8)) 
    {
        $self->{level}{$left} = $right;
    }
    # That value can be multi-byte, of several varieties
        
    elsif ($right == 8) 
    {   # next byte, num (7-bit) only
        $self->{level}{$left} = ord (substr ($$buf, ++$$i, 1)) & MASK;
    }
    elsif ($right == 9) 
    {   # num, then char
        $num = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $char = chr (ord (substr ($$buf, ++$$i, 1)) & MASK);
        $self->{level}{$left} = $num.$char;
    }
    elsif ($right == 10) 
    {   # num, then string
        $num = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $str = get_ascii_string( $buf, $i );
        if ($self->{documentary})
        {
            # Nasty hack for when this string contains stuff
            # like 1[3], which could be BETA formatting code,
            # but isn't (see Fouilles de Delphes in the
            # Cornell inscriptions database).
            $str =~ s#([\[\]])#\`$1\`#g; #These are BETA null chars.
        }
        $self->{level}{$left} = $num.$str;
    }
    elsif  ($right == 11) 
    {   # next two bytes hide a 14-bit number
        $top_byte = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $low_byte = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $self->{level}{$left} = ($top_byte << 7) + $low_byte;
    }
    elsif  ($right == 12) 
    {   # 2-byte num, then char
        $top_byte = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $low_byte = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $char = chr (ord (substr ($$buf, ++$$i, 1)) & MASK);
        $num = ($top_byte << 7) + $low_byte;
        $self->{level}{$left} = $num.$char;
    }
    elsif  ($right == 13) 
    {   # 2-byte num, then string
        $top_byte = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $low_byte = ord (substr ($$buf, ++$$i, 1)) & MASK;
        $num = ($top_byte << 7) + $low_byte;
        $str = get_ascii_string( $buf, $i );
        $self->{level}{$left} = $num.$str;
    }
    elsif  ($right == 14) 
    {   # Is this correct? Only append a char to the (unincremented) counter?
        # Apparently confirmed by phi2ltx.
        # die("I don't understand a right nybble value of 14");
        $char = chr (ord (substr ($$buf, ++$$i, 1)) & MASK);
        $self->{level}{$left} .= $char;
    } 
    elsif  ($right == 15) 
    {   # a string comes next 
        $str = get_ascii_string( $buf, $i ); 
        $self->{level}{$left} = $str; 
        ##print ")".$left.": ".$self->{level}{$left}."\n" if $self->{debug};
    } 
    else 
    {   #no other possibilities 
        die ("I've fallen and I can't get up!"); 
    }
}

######################## Output munging routines ####################

sub print_output
{
    my ($self, $ref) = @_;
    
    # Replace runs of non-ascii with newlines and add symbol for
    # the base language of the text at the start of the excerpt and
    # after every run of non-ascii (only for documentary texts such
    # as the DDP, which have lots of unterminated Latin embedded in
    # non-ascii). Add null char afterwards, in case line begins with
    # a number
    
    my $lang = $self->{current_lang} || 'g';
    my $newline = "\n"; 
    $newline = "\n" . (($lang =~ m/g/) ? '$' : '&') . "ˇÆˇ" if $self->{documentary};
    $$ref =~ s/[\x01-\x06\x0e-\x1f\x80-\xff]+/$newline/g ;
                
    # Remove trailing nulls
    $$ref =~ s/[\x00]+//g;
    
    if (defined $self->{aux_out})
    {
        print { $self->{aux_out} } ($$ref);
    }
    return if $self->{output_format} eq 'none';     
    
    $self->format_output($ref);
    print $$ref;
}               

sub format_output
{
    my ($self, $ref, $current_lang) = @_;
    
    my $lang = $self->{current_lang} || 'g';
    $lang = $current_lang if $current_lang;
    $self->{perseus_morph} = 0 if ($Diogenes::encoding{$self->{encoding}}{remap_ascii});
    
    # Get rid of null chars.  We can't do this last, as we would like,
    # because this represents a grave accent for many encodings
    # (e.g. displaying Ibycus via HTML).  We have to leave something
    # here as a marker or formatting gets confused.  So all formats
    # must remember to remove this string.
    $$ref =~ s/\`/ˇÆˇ/g;

    if ($self->{type} eq 'cop' and $lang !~ m/l/)
    {
        $self->coptic_with_latin($ref);
    }
    elsif ($lang eq 'g')
    {
        $self->greek_with_latin($ref);
    }
    else
    {
        $self->latin_with_greek($ref);
    }
    
    
    $self->beta_formatting_to_ascii ($ref) if $self->{output_format} eq 'ascii';
    # use beta_formatting_to_ascii with encoding Ibycus for repaging
    # output PAM 090102
    $self->beta_formatting_to_ascii ($ref) if $self->{output_format} eq 'repaging';
    $self->beta_to_latex ($ref) if $self->{output_format} eq 'latex';
    if ($self->{output_format} eq 'html')
    {
        if ($Diogenes::encoding{$self->{encoding}}{remap_ascii})
        {
            # This is a Greek font that remaps the ascii range, and so
            # it is almost certainly not safe to parse the output as
            # Beta, since the Greek encoding will contain HTML Beta
            # control and formatting chars.  So we just escape the
            # HTML codes, and send it as-is
            $self->html_escape($ref);
            $$ref =~ 
                s#ˇˇ1#<FONT FACE="$Diogenes::encoding{$self->{encoding}}{font_name}">#g;
            $$ref =~ s#ˇˇ2#</FONT>#g;
            $$ref = "\n<pre>\n$$ref\n</pre>\n";
        }
        else
        {
            $self->beta_to_html ($ref);
        }
    }
    $$ref =~ s#ˇÆˇ##g;
}

sub greek_with_latin
{
    my ($self, $ref) = @_;
    $$ref =~ s/([^\&]*)([^\$]*)/
                                        my $gk = $1 || '';
                                        if ($gk)
                                        {
                                                $self->{perseus_morph} ? 
                                                  $self->perseus_handler(\$gk, 'greek') 
                                                : $self->{greek_handler}->(\$gk);
                                        }
                                        my $lt = $2 || '';
                                        if ($lt)
                                        {
                                                $self->{perseus_morph} ? 
                                                  $self->perseus_handler(\$lt, 'la') 
                                                : $self->{latin_handler}->(\$lt);
                                        }
                                        $gk.$lt;
                                        /gex;
}

sub latin_with_greek
{
    my ($self, $ref) = @_;
    $$ref =~ s/([^\$]*)([^\&]*)/
                                        my $lt = $1 || '';
                                        if ($lt)
                                        {
                                                $self->{perseus_morph} ? 
                                                  $self->perseus_handler(\$lt, 'la') 
                                                : $self->{latin_handler}->(\$lt);
                                        }
                                        my $gk = $2 || '';
                                        if ($gk)
                                        {
                                                $self->{perseus_morph} ? 
                                                  $self->perseus_handler(\$gk, 'greek') 
                                                : $self->{greek_handler}->(\$gk);
                                        }
                                        $lt.$gk;
                                        /gex;
}

sub perseus_handler
{
    my ($self, $ref, $lang) = @_;
    my $target = $self->{perseus_target} ? " target=ˇˇø$self->{perseus_target}ˇˇø" : '';
    my $out = '';
    my ($h_word, $h_space) = ('', '');
    # $punct are not part of the word, but should not interfere in morph lookup
    my ($beta, $punct) = $lang eq 'greek' ? ('A-Z/\\\\|+)(=*~hit\'', '\\[\\]!?.')
        : ('A-Za-z~\'', '\\[\\]!?.+\\\\/=');  
    while ($$ref =~ m/([$beta$punct\d]*)([^$beta]*)/g)
    {
        my $word  = $1 || '';
        my $space = $2 || '';
        my $link = $h_word . $word;
        $word = $h_word . $h_space . $word;
        #print STDERR ">>$word\n";
        if ($word =~ m#~~~\d+~~~\d+~~~\d+~~~#)
        {       # This is a context/divider
            $out .= $word;
            next;
        }
        
        if ($space =~ m/^-/)
        {       # Carry over hyphenated parts
            ($h_word, $h_space) = ($word, $space);
        }
        else
        {
            $link =~ s/[$punct\d]//g;
            # Perseus morph parser takes Beta, but lowercase <- NOT ANYMORE
            # $link =~ tr/A-Z/a-z/ if $lang eq 'greek'; 
            # $link =~ s#\\#/#g if $lang eq 'greek';    # normalize barytone
      
            # At some point perseus stopped accepting beta code,
            # particularly for psi, chi and xi, but to avoid future
            # problems, we go the whole hog here and translate into
            # Perseus-style.  Note that Perseus still expects r(ei,
            # rather than rhei.
            $link = beta_to_perseus($link) if $lang eq 'greek'; 

            $link =~ s/~[Hh]it~([^~]*)~/$1/g; 
            # Encode word itself
            if ($lang eq 'greek')
            {
                $self->{greek_handler}->(\$word); 
                $self->{greek_handler}->(\$space); 
            }
            elsif ($lang eq 'la')
            {
                $self->{latin_handler}->(\$word); 
                $self->{latin_handler}->(\$space); 
            }
            else
            {
                die "What language is $lang?\n"
            }
            $self->html_escape(\$word);
            $self->html_escape(\$space);
            # ˇˇ% gets changed to % and ˇˇø to "
            # URL escape (from CGI.pm)
            $link =~ s/([^a-zA-Z0-9_.-])/'ˇˇ'.uc sprintf("%%%02x",ord($1))/eg; 
            my $html = qq(<a$target href=ˇˇø$self->{perseus_server}cgi-bin/morphindex?lookup=$link&.submit=Analyze+Form&lang=$lang&formentry=1ˇˇø>$word</a>); 
            $out .= $html.$space;
            ($h_word, $h_space) = ('', '');
        }
    }
    $$ref = $out;
}

sub beta_to_perseus
{
    my $word = shift;
    $word =~ tr/A-Z/a-z/; 
    $word =~ s/[^a-z(]//g;
    $word =~ s/^\(/H/g;
    $word =~ s/^([aeiouhw]+)\(/H$1/g;

    $word =~ s/h/e^/g;
    $word =~ s/q/th/g;
    $word =~ s/c/X/g;
    $word =~ s/f/ph/g;
    $word =~ s/x/ch/g;
    $word =~ s/y/ps/g;
    $word =~ s/w/o^/g;

    $word =~ tr/A-Z/a-z/; 
    return $word;
}

########################################################################
#                                                                      #
# Subroutine to convert a string from raw BETA code to Pierre MacKay's #
# ibycus format.                                                       #
#                                                                      #
########################################################################

sub beta_encoding_to_ibycus 
{
    # Unlike many other encodings, Ibycus takes care of medial/final
    # sigmas for us, so we only have to worry about explicit S1, etc.
    # The byte ˇ (\xff) is never used in UTF-8
    my ($self, $ref) = @_;
    $$ref =~ tr/A-Z/a-z/;
    $$ref =~ s/s1/s\|/g;
    $$ref =~ s/s2/j/g;
    $$ref =~ s/s3/c+/g;
    $$ref =~ s/'/ˇ£ˇ/g; # Converted to {'} or '' later
    $$ref =~ s/\//'/g;
    $$ref =~ s/\\/`/g;
    $$ref =~ s/\*(\W*)(\w)/$1\u$2/g;
    $$ref =~ s#;#ˇßˇ#g; # Must be converted to "?" *after* ?'s for underdots are done
    $$ref =~ s#:#;#g;
    $$ref =~ s#\[1#ˇ´ˇ(ˇªˇ#g; # These punctuation marks can cause trouble
    $$ref =~ s#\]1#ˇ´ˇ)ˇªˇ#g;
    $$ref =~ s#\[(?!\d)#ˇ´ˇ[ˇªˇ#g;
    $$ref =~ s#\](?!\d)#ˇ´ˇ]ˇªˇ#g;
    $$ref =~ s#J#{\\nrm{}h}#g;  # Early orthography in epigraphical corpus
}

sub beta_encoding_to_transliteration 
{
    # Just like Ibycus above, but a bit cleaner to read as text
    my ($self, $ref) = @_;
    $$ref =~ tr/A-Z/a-z/;
    $$ref =~ s/s1/s\|/g;
    $$ref =~ s/s2/j/g;
    $$ref =~ s/s3/c+/g;
    $$ref =~ s/'/$self->{ibycus4} ? '{\'}' : '\'\''/ge;
    $$ref =~ s/\//'/g;
    $$ref =~ s/\\/`/g;
    $$ref =~ s/\*(\W*)(\w)/$1\u$2/g;
    $$ref =~ s#;#?#g; 
    $$ref =~ s#:#;#g;
    $$ref =~ s#\[1#(#g; 
    $$ref =~ s#\]1#)#g;
    $$ref =~ s#\[(?!\d)#[#g;
    $$ref =~ s#\](?!\d)#]#g;
}


sub beta_encoding_to_latin1
{
    # Watch out!  This introduces non-ascii chars.
    my $ref = shift;
    
    my %acute = (a => '·', e => 'È', i => 'Ì', o => 'Û', u => '˙', 
                 A => '¡', E => '…', I => 'Õ', O => '”', U => '⁄'); 
    my %grave = (a => '‡', e => 'Ë', i => 'Ï', o => 'Ú', u => '˘', 
                 A => '¿', E => '»', I => 'Ã', O => '“', U => 'Ÿ'); 
    my %diaer = (a => '‰', e => 'Î', i => 'Ô', o => 'ˆ', u => '¸', 
                 A => 'ƒ', E => 'À', I => 'œ', O => '÷', U => '‹'); 
    my %circm = (a => '‚', e => 'Í', i => 'Ó', o => 'Ù', u => '˚', 
                 A => '¬', E => ' ', I => 'Œ', O => '‘', U => '€'); 


    $$ref =~ s/([aeiouAEIOU])\//$acute{$1}||'?'/ge;
    $$ref =~ s/([aeiouAEIOU])\\/$grave{$1}||'?'/ge;
    $$ref =~ s/([aeiouAEIOU])\+/$diaer{$1}||'?'/ge;
    $$ref =~ s/([aeiouAEIOU])\=/$circm{$1}||'?'/ge;
}

sub utf8_to_beta_encoding
{
    # For input (esp. to browser)
    my $ref = shift;
    
    my %accents = ( 
        '225' => 'a/', '233' => 'e/', '237' => 'i/', '243' => 'o/', '250' =>'u/', 
        '193' => 'A/', '201' => 'E/', '205' => 'I/', '211' => 'O/', '218' => 'U/',
        '224' => 'a\\', '232' => 'e\\', '236' => 'i\\', '242' => 'o\\', '249' => 'u\\', 
        '192' => 'A\\', '200' => 'E\\', '204' => 'I\\', '210' => 'O\\', '217' => 'U\\',
        '228' => 'a+', '235' => 'e+', '239' => 'i+', '246' => 'o+', '252' => 'u+', 
        '196' => 'A+', '203' => 'E+', '207' => 'I+', '214' => 'O+', '220' => 'U+',
        '226' => 'a=', '234' => 'e=', '238' => 'i=', '244' => 'o=', '251' => 'u=', 
        '194' => 'A=', '202' => 'E=', '206' => 'I=', '212' => 'O=', '219' => 'U='
    ); 
    
    $$ref =~ s#([\x80-\xff]+)#      my @chars=unpack'U*',$1; 
                                    my $out = '';
                                    map { $out .= $accents{$_} } @chars;
                                    $out;
              #ge;

}


sub beta_encoding_to_latin_tex
{
    my $ref = shift;
    
    $$ref =~ s#([\s\n~])"#$1``#g;
    $$ref =~ s#"#''#g;
    $$ref =~ s#([aeiouAEIOU])\/#\\'{$1}#g;
    $$ref =~ s#([aeiouAEIOU])\\#\\`$1;#g;
    $$ref =~ s#([aeiouAEIOU])\=#\\^{$1}#g;
    $$ref =~ s#([aeiouAEIOU])\+#\\"{$1}#g;
    $$ref =~ s/([\%\$\@\#])/\\$1/g;
}

sub beta_latin_to_utf
{
    my $ref = shift;

    # First, we translate to iso-8859-1
    beta_encoding_to_latin1($ref);

    # Then to utf-8 (but we don't use "use utf8")
    $$ref =~ s#(ˇ.ˇ|[\x80-\xff])#my $c = $1;
                                if ($c =~ m/ˇ.ˇ/)
                                {       
                                        $c;
                                }
                                else
                                {
                                        chr(((ord $c) >> 6) | hex 'c0') . 
                                        chr((ord $c & hex '3f') | hex '80') ;
                                }
                                #ge;
}

sub beta_encoding_to_html
{
    my ($self, $ref) = @_;
    
    # these are really part of the encoding
    $$ref =~ s#([aeiouAEIOU])\/#&$1acute;#g;
    $$ref =~ s#([aeiouAEIOU])\\#&$1grave;#g;
    $$ref =~ s#([aeiouAEIOU])\=#&$1circ;#g;
    $$ref =~ s#([aeiouAEIOU])\+#&$1uml;#g;
    
    if ($Diogenes::encoding{$self->{encoding}}{remap_ascii})
    {
        # This is going to the browser directly without re-formatting in HTML,
        # so we might as well strip the junk out here
        $self->beta_formatting_to_ascii($ref);
    }
}
sub beta_formatting_to_ascii 
{
    my ($self, $ref) = @_;
    
    # Turn off warnings when we access phantom elements of the following
    # arrays.
    local $^W = 0;
    
    my @punct = (qw#° ? * / ! | = + % & : . * °° ∂ ¶ ¶ ¶¶ ' - #, 
                 '', '', '', '', qw# ~ ∏ Ø ∞ ® #);  
    my @bra   = ('', '(', qw/< { [[ [ [ [ [ [ [ ( -> [ [ [ [[ [[/, '', '', qw/{ { { {/);
    my @ket   = ('', ')', qw/> } ]] ] ] ] ] ] ] ) <- ] ] ] ]] ]]/, '', '', qw/} } } }/);
    
    $$ref =~ s#_#-#g if $self->{documentary};
    $$ref =~ s#_# -- #g;
    
    #       $$ref =~ s#\?#\(?\)#g   unless $self->{current_lang} eq 'l';
    $$ref =~ s#\!#.#g               unless $self->{current_lang} eq 'l';
    $$ref =~ s#[\&\$]\d*##g;
    $$ref =~ s#%(\d+)#$punct[$1]#g;
    $$ref =~ s#\"\d*#\"#g;
    
    $$ref =~ s#@\d+#\ \ #g;
    $$ref =~ s#@#\ \ #g;
    $$ref =~ s#\^\d+#\ \ \ \ #g;
    
    # Get rid of numbers after brackets, etc
    $$ref =~ s#([\<\>\{\}])\d+#$1#g;
    # Get rid of # except for &#0000; etc.
    $$ref =~ s/#\d+/#/g unless $self->{encoding} =~ m/Unicode_Entities/;

    $$ref =~ s#\[(\d+)#$bra[$1]#g; 
    $$ref =~ s#\](\d+)#$ket[$1]#g;
    
    $$ref =~ s#ˇßˇ#?#g;
    $$ref =~ s#sˇ£ˇ#$self->{ibycus4} ? 's\'' : 's\'\''#ge; # stop spurious final sigmas
    $$ref =~ s#ˇ£ˇ#$self->{ibycus4} ? '{\'}' : '\'\''#ge;
    $$ref =~ s#ˇ´ˇ#{#g;
    $$ref =~ s#ˇªˇ#}#g;

    # Capitalization of vowels with diacrits won't work with many 
    # of the wierder encodings
    if ($self->{current_lang} eq 'g' 
        and $self->{encoding} !~ m/Ibycus/i
        and $self->{encoding} !~ m/Transliteration/i
        and $self->{encoding} !~ m/Beta/i       )
    {
        $$ref =~ s#~[Hh]it~([^~]+)~#->$1<-#g;
    }
    else
    {
        $$ref =~ s#~[Hh]it~([^~]+)~#\U$1\Q#g;
    }
    $$ref =~ s#~~~(\d\d\d\d)~~~(\d\d\d)~~~(\d+)~~~#~~~~~~~~~~~~~~~~~~~~~~~~~~~#g;
}


sub html_escape
{
    my ($self, $ref) = @_;
#   $$ref =~ s/&/&amp;/g;
    $$ref =~ s/&(?!#|[aeiouAEIOU](?:acute|grave|circ|uml);)/&amp;/g;
    $$ref =~ s/>/&gt;/g;
    $$ref =~ s/</&lt;/g;

}

##############################################################################
# Subroutine to convert the formatting codes in the search result to html    #
# markup.  Feed me one entry at a time, please.                              #
##############################################################################

sub beta_to_html 
{
    my ($self, $ref) = @_;
    
    # Turn off warnings when we access phantom elements of the following
    # arrays.
    local $^W = 0;

    # Here is some data used for turning BETA formatting into html:
    my @punct = ('', '?', '*', '/', '!', '&brvbar;', '=', '+', '%', '&amp;',
                 ':', '.', '*', '&#135;', '&para;', '&brvbar;', '&brvbar;', '&brvbar;',
                 '\'', '-');  
    my @bra   = ('', '(', '&lt;', '{', '[[', '[', '[', '[', '[', '[', '[', '(',
                 '->', '[', '[', '[', '[[', '[[');
    my @ket   = ('', ')', '&gt;', '}', ']]', ']', ']', ']', ']', ']', ']', ')',
                 '<-', ']', ']', ']', ']]', ']]');

    # more could be done with < and >, but mark them with braces for now
    # escape all < and > so as not to confuse html
    # escape & when not followed by # (html numerical entity)
    unless ($self->{perseus_morph})
    {       # Perseus links will already be html-escaped
        $$ref =~ s/&(?!#|[aeiouAEIOU](?:acute|grave|circ|uml);)/&amp;/g;
        $$ref =~ s#\<#&lt;#g;
        $$ref =~ s#\>#&gt;#g;
    }
    $$ref =~ s#&lt;1(?!\d)((?:(?!\>|$).)+)(?:&gt;1(?!\d))#<u>$1</u>#gs;
    
    # undo the business with ~hit~...~
    #$$ref =~ s#~[Hh]it~([^~]*)~#<b>$1</b>#g;
    $$ref =~ s#~[Hh]it~([^~]*)~#<u>$1</u>#g;

    # " (quotes)
    $$ref =~ s/([\$\&\d\s\n~])\"3\"3/$1&#147;/g;
    $$ref =~ s/([\$\&\d\d\s\n~])\"3/$1&#145;/g;
    $$ref =~ s/\"3\"3/&#148;/g;
    $$ref =~ s/\"3/&#146;/g;

    $$ref =~ s/([\$\&\d\s\n~])\"[67]/$1&laquo;/g;
    $$ref =~ s/\"[67]/&raquo;/g;

    $$ref =~ s/([\$\&\d\s\n~])\"\d?/$1&#147;/g;
    $$ref =~ s/\"\d?/&#148;/g;
    $$ref =~ s/\"\d+/&quot;/g;
    
    $$ref =~ s#ˇˇ1#<FONT FACE="$Diogenes::encoding{$self->{encoding}}{font_name}">#g;
    $$ref =~ s#ˇˇ2#</FONT>#g;
    $$ref =~ s#ˇˇø#"#g;

    # Pseudo-letterspacing -- is it worth the hassle?.
#       # Doesn't work yet -- ascii Greek encoding needs totally different rules from
#       # UTF-8, and a latin transliteration needs other rules again.
#       my %letter = (Ibycus => '&[^;]+;|[a-zA-Z][)(\'\`|+=?]?',
#                                 Beta   => '&[^;]+;|[A-Z*][)(\/\\|+=?]?',
#                                 Unicode_Entities => '&[^;]+;');
#       $$ref =~ s{&lt;2\d((?:[^&]|&[^g][^t])*?)(?:&gt;2\d|ˇˇ)}{my $rep = $1; 
#                       $rep =~ s/[Xx]it([^£]*)£/$1/g; 
##                      $rep =~ s/(&[^;]+;|[a-zA-Z](?=[&a-zA-Z]))/$1&nbsp;/g; 
#                       $rep =~ s/(&[^;]+;|[\x80-\xff]+|.(?![\s]))/$1&nbsp;/g; 
#                       #$rep =~ s/(&#\d+;)(?=[&a-zA-Z])/$1<spacer type=horizontal size=3>/g; 
#                       $rep}gex;
    
    $$ref =~ s#&lt;\d*#&lt;#g;
    $$ref =~ s#&gt;\d*#&gt;#g;

    # Note that $ must be escaped in these regexen, or the $] is parsed as a var.
    $$ref =~ s#(?:\$|&amp;)10((?:(?!\$|&amp;).)+)#<font size=-1>$1</font>#gs;
    $$ref =~ s#(?:\$|&amp;)11((?:(?!\$|&amp;).)+)#<font size=-1><b>$1</b></font>#gs;
    $$ref =~ s#(?:\$|&amp;)13((?:(?!\$|&amp;).)+)#<font size=-1><i>$1</i></font>#gs;
    $$ref =~ s#(?:\$|&amp;)14((?:(?!\$|&amp;).)+)#<font size=-1><sup>$1</sup></font>#gs;
    $$ref =~ s#(?:\$|&amp;)15((?:(?!\$|&amp;).)+)#<font size=-1><sub>$1</sub></font>#gs;
    $$ref =~ s#&amp;16((?:(?!\$|&amp;).)+)#<sup><i>$1</i></sup>#gs;
    $$ref =~ s#(?:\$|&amp;)20((?:(?!\$|&amp;).)+)#<font size=+1>$1</font>#gs;
    $$ref =~ s#(?:\$|&amp;)21((?:(?!\$|&amp;).)+)#<font size=+1><b>$1</b></font>#gs;
    $$ref =~ s#(?:\$|&amp;)23((?:(?!\$|&amp;).)+)#<font size=+1><i>$1</i></font>#gs;
    $$ref =~ s#(?:\$|&amp;)24((?:(?!\$|&amp;).)+)#<font size=+1><sup>$1</sup></font>#gs;
    $$ref =~ s#(?:\$|&amp;)25((?:(?!\$|&amp;).)+)#<font size=+1><sub>$1</sub></font>#gs;
    $$ref =~ s#(?:\$|&amp;)30((?:(?!\$|&amp;).)+)#<font size=-2>$1</font>#gs;
    $$ref =~ s#(?:\$|&amp;)40((?:(?!\$|&amp;).)+)#<font size=+2>$1</font>#gs;
    
    $$ref =~ s#(?:\$|&amp;)1((?:(?!\$|&amp;).)+)#<b>$1</b>#gs;
    $$ref =~ s#(?:\$|&amp;)3((?:(?!\$|&amp;).)+)#<i>$1</i>#gs;
    $$ref =~ s#(?:\$|&amp;)4((?:(?!\$|&amp;).)+)#<sup>$1</sup>#gs;
    $$ref =~ s#(?:\$|&amp;)5((?:(?!\$|&amp;).)+)#<sub>$1</sub>#gs;
    $$ref =~ s#\&amp;[678]((?:(?!\$|&amp;).)+)#<font size=-1>\U$1\E</font>#gs;
    $$ref =~ s#\$\d6((?:(?!\$|&amp;).)+)#<b><sup>$1</sup></b>#gs;

    $$ref =~ s#\&amp\;#<basefont>#g;
    $$ref =~ s#\$##g;
    
    # BETA { and } -- title, marginalia, etc.
    # what to do about half-cut off bits? must stop at a blank line.
    #
    $$ref =~ s#\{1((?:[^\}]|\}[^1]|\})*?)(?:\}1|$)#<h4>$1</h4>#g;
    $$ref =~ s#((?:[^\}]|\}[^1]|\})*?)\}1#<h4>$1</h4>#g;
    # Servius
    $$ref =~ s#\{43((?:[^\}]|\}[^4]|\}4[^3])*?)(?:\}43|$)#<i>$1</i>#g;
    $$ref =~ s#((?:[^\}]|\}[^4]|\}4[^3])*?)\}43#<i>$1</i>#g;
    $$ref =~ s#\{\d+([^\}]+)(?:\}\d+|$)#<h5>$1</h5>#g;
    
    # record separators
    if ($Diogenes::cgi_flag and $self->{cgi_buttons})
    {
        $$ref =~ s#~~~(\d\d\d\d)~~~(\d\d\d)~~~(\d+)~~~#<TABLE cellpadding=0 border=0><TR><TD><input type=submit value="$self->{cgi_buttons}" name="GetContext~~~$1~~~$2~~~$3">\n</TD></TR></TABLE><hr>\n#g;
        
    }
    else
    {
        $$ref =~ s#~~~~~+#<hr>\n#g;
        $$ref =~ s#~~~(\d\d\d\d)~~~(\d\d\d)~~~(\d+)~~~#<hr>\n#g;
        $$ref =~ s#^\$\-?$#\$<p> #g;
    }
    
    # eliminate `#' except as part of &#nnn;
    #$$ref =~ s/(?<!&)#\d*([^;])/$1/g;  
    
    # some punctuation
    $$ref =~ s/_/\ &#151;\ /g;


    # Perseus links use % for URL-escaped data in the href, so these are 
    # written as ˇˇ% until now 
    # % (more punctuation)
    # s/([])%24/&$1tilde;/g;
    $$ref =~ s#(?<!ˇˇ)%(\d+)#$punct[$1]#g;
    $$ref =~ s/(?<!ˇˇ)%/\&\#134\;/g;
    $$ref =~ s/ˇˇ%/%/g;
    
    $$ref =~ s#sˇ£ˇ#$self->{ibycus4} ? 's\'' : 's\'\''#ge; # stop spurious final sigmas
    $$ref =~ s#ˇ£ˇ#$self->{ibycus4} ? '{\'}' : '\'\''#ge;
    $$ref =~ s#ˇßˇ#?#g;
    $$ref =~ s#ˇ´ˇ#{#g;
    $$ref =~ s#ˇªˇ#}#g;
    
    # @ (whitespace)
    $$ref =~ s#@(\d+)#'&nbsp;' x $1#ge;
    $$ref =~ s#(\ \ +)#'&nbsp;' x (length $1)#ge;
    $$ref =~ s#@#&nbsp;#g;
    
    # ^
    $$ref =~ s#\^(\d+)#my $w = 5 * $1;qq{<spacer type="horizontal" size=$w>}#ge;
    
    # [] (brackets of all sorts)
    $$ref =~ s#\[(\d+)#$bra[$1]#g; 
    $$ref =~ s#\](\d+)#$ket[$1]#g;
    
    
    $$ref =~ s#\n\s*\n#<p>#g; 
    $$ref =~ s#\n#<br>\n#g;
    $$ref =~ s#<[Hh]\d></[Hh]\d>##g; # void marginal comments
#       These have to stay, since babel, Ibycus uses ` as the grave accent
    
}

########################################################################
#                                                                      #
# Method to convert the formatting codes in the search result to latex #
# markup.   For Greek mostly.                                          #
#                                                                      #
########################################################################

sub beta_to_latex 
{
    my ($self, $ref) = @_;
    
    # We may get many chunks now
    $$ref = "xxbeginsamepage\n" . $$ref . "ˇˇˇˇendsamepage\n" 
        unless $$ref =~ m/^\&\nIncidence of all words as reported by word list:/;
    
    # record separators
    $$ref =~ s#~~~~~*\n#ˇˇˇˇforcepagebreakˇˇˇˇ#g;
    $$ref =~ s#~~~\d\d\d\d~~~\d\d\d~~~\d+~~~\n#ˇˇˇˇforcepagebreakˇˇˇˇ#g;
    $$ref =~ s#\n\&\&\n+#ˇˇˇˇforcepagebreakˇˇˇˇ\n\n\&#g;
    

    # \familydefault to ibycus means that marginal notes and such are always set
    # in greek
    my ($small, $large);
    if ($self->{printer}) 
    {
        $small = '{8}{10}';
        $large = '{14}{17}';
    }
    else 
    {
        $small = '{14}{21}';
        $large = '{21}{25}';
    }

    # Here is some data used for turning BETA formatting codes into a twisted
    # form of LaTeX.
    
    local $^W = 0;

    my @punct = (
        '', qw#\textrm{£} $*$ / ! \ensuremath{|} $=$ $+$ \% \& © . $*$#, 
        '{\ddag}', '{\P}', '\ensuremath{|}','\ensuremath{|}', '\ensuremath{|}', 
        '\'', '-', '', '', '', '', '', '', '', '', '', '', '{})', '{}(', '{}\'', 
        '{}`', '{}\~{}', '{})\'', '{}(\'', '{}(`', '{}(=', '{}\"{~}');  
    my @bra   = ('', '\ensuremath{(}', '\ensuremath{<}', 
                 qw/\{ [[ [ [ [ [ [ [ ( -> [ [ [ [[ [[/, '', '', qw/\{ \{ \{ \{/);
    my @ket   = ('', '\ensuremath{)}', '\ensuremath{>}', 
                 qw/\} ]] ] ] ] ] ] ] ) <- ] ] ] ]] ]]/, '', '', qw/\} \} \} \}/);
    if ($self->{ibycus4})
    {   #iby4extr
        $bra[5] = "{\\bracketleftbt}";
        $ket[5] = "{\\bracketrightbt}";
    }
    my @gk_font = (
        '', '\fontseries{b}', '', '\fontshape{sl}','','','','','', '', 
        "\\fontsize$small", "\\fontsize$small\\fontseries{b}", '', 
        "\\fontsize$small\\fontshape{sl}",'','','','','','',"\\fontsize$large",
        "\\fontsize$large\\fontseries{b}", '', "\\fontsize$small\\fontshape{sl}");
    my @rm_font = ('', '\fontseries{bx}', '', '\fontshape{it}','','',
                   '\fontshape{sc}','\fontshape{sc}','\fontshape{sc}','',
                   "\\fontsize$small", "\\fontsize$small\\fontseries{bx}",
                   '',"\\fontsize$small\\fontshape{it}",'','','','','','',
                   "\\fontsize$large", "\\fontsize$large\\fontseries{bx}", 
                   '', "\\fontsize$small\\fontshape{it}");
    my @sym = (
        '', '{\greek{k+}}', '\ensuremath{\cdot}', '{\greek{k+}}', '', '{\greek{s+}}',
        '\makebox[0pt][l]{\hspace{-2mm}\rule[-3.5mm]{5mm}{.2mm}\rule[-5mm]{0mm}{9mm}}', 
        '.', 
        '\makebox[0pt][l]{\hspace{-2mm}\rule[-3.5mm]{5mm}{.2mm}\rule[-5mm]{0mm}{9mm}}', 
        '', '\ensuremath{\supset}', '', '--',
        '\ensuremath{\divideontimes}', '\dipleperi{}',
        '\ensuremath{>}');

    # If we are generating postscript or PDF for portability, we don't
    # want any bitmapped fonts
    my @oddquotes = $self->{psibycus} ?
        ('{,,}',
         '{,}',
         '{\\greek{<<}}',
         '{\\greek{<<}}',
         '{\\greek{>>}}',
         '{\\greek{>>}}' 
        )  :
        ('{\\fontencoding{T1}\\fontfamily{cmr}\\selectfont\\quotedblbase}',
         '{\\fontencoding{T1}\\fontfamily{cmr}\\selectfont\\quotesinglbase}',
         '{\\fontencoding{T1}\\fontfamily{cmr}\\selectfont\\guillemotleft}',
         '{\\fontencoding{T1}\\fontfamily{cmr}\\selectfont\\guilsinglleft}',
         '{\\fontencoding{T1}\\fontfamily{cmr}\\selectfont\\guillemotright}',
         '{\\fontencoding{T1}\\fontfamily{cmr}\\selectfont\\guilsinglright}'  ) ;
    
    # BETA { and } -- title, marginalia, etc.
    
    #$$ref =~ s#\{1(?!\d)(([\$\&]\d*)?(?:[^\}]|\}[^1]|\})*?)(?:\}1(?!\d)|ˇˇ)#titlebox£$1£$2£#g;
    $$ref =~ s#\{1(?!\d)([\$\&]\d*)?((?:(?!\}1(?!\d)|ˇˇ).)+)(?:\}1(?!\d))?#titlebox£$1£$2£#gs;
    #$$ref =~ s#\{2(?!\d)((?:[^\}]|\}[^2]|\})*?)([\&\$]?)(?:\}2(?!\d)|ˇˇ)#\\marginlabel£$1£$2#g;
    $$ref =~ s#\{2(?!\d)((?:(?!\}2(?!\d)|ˇˇ).)+)(?:\}2(?!\d))?#\\marginlabel£$1£#gs;
    #$$ref =~ s#\{(\D[^\}]*?)([\$\&]?)\}(?:\s*\n)?#\\marginlabel£$1£$2#g;
    $$ref =~ s#\{(\D[^\}]*?)([\$\&]?)\}(?:\s*\n)?#\\marginlabel£$1$2£#g;
    ##$$ref =~ s#\{\d*([^\}]*)(?:\}\d*|ˇˇ)#ital¢$1¢#g;
    #$$ref =~ s#\{43((?:[^\}]|\}[^4]|\}4[^3])*?)(?:\}43|ˇˇ)#ital¢$1¢#g;
    #$$ref =~ s#((?:[^\}]|\}[^4]|\}4[^3])*?)\}43#ital¢$1¢#g;
    $$ref =~ s#\{43((?:(?!\}43|ˇˇ).)+)(?:\}43)?#ital¢$1¢#g;
    $$ref =~ s#(?:\{43)?((?:(?!\}43|ˇˇ).)+)(?:\}43)#ital¢$1¢#g;
    # These {} signs are too multifarious in the papyri to do much with them -- and
    # if we make them italicized, then they often catch and localize wrongly font
    # shifts from rm to gk.
    $$ref =~ s#\{\d*([^\}]*)(?:\}\d*|ˇˇ)#{$1}#g;
    
    # escape all other { and } so as not to confuse latex
    $$ref =~ s#\{\d*#\\\{#g;
    $$ref =~ s#\}\d*#\\\}#g;
    
    # now we can safely use { and } -- undo the business with £
    # the eval block is for cases where the ~hit~...~ spans two lines.
    # and to make it spit out the record delimiter when it eats that.
    $$ref =~ s#titlebox£([^£]*)£([^£]*)£#
                        my $rep = "\\titlebox{$1}{$2}";
                        $rep =~ s/~hit~([^~\n]*)\n([^~]*)~/~hit~$1~\n~hit~$2~/g;
                        $rep =~ s/(\n+\~+\n+)\}(\{[^\}]*\})$/\}$2$1/g;
                        $rep#gex; 

        # The font command to switch back is usually *inside* the marginal note!
    $$ref =~ s#\\marginlabel£([^£]*)£#my $label = $1;
                                my $font = $1 if $label =~ m/([\&\$]\d*)$/;
                                "\\marginlabel{$label}$font"#gex;
    $$ref =~ s#ital¢([^¢]*)¢#\\emph{$1}#gi;
    
    # Pseudo-letterspacing with \,:
    # Real letterspacing separates accents from their letters.
    # This method screws up medial sigma, so we have to force it.
    
    $$ref =~ s#\<20((?:(?!\>20|ˇˇ).)+)(?:\>20)?#my $rep = $1; 
                        $rep =~ s/(['`=)(]*[A-Z ][+?]*)(?=[a-zA-Z])/$1\\,/g; 
                        $rep =~ s/([a-z]['`|+=)(?]*)(?=[a-zA-Z])/$1\\,/g; 
                        $rep =~ s/s\\,/s\|\\,/g; 
                        $rep =~ s/$/\\,/; 
                        $rep =~ s/~h\\,i\\,t~/~hit~/; 
                        $rep#gsex;

    $$ref =~ s#\<(\D(?:[^\>\n]|\>\d)*?)(?:\>|\n)#\\ensuremath\{\\overline\{\\mbox\{$1\}\}\}#g;
    $$ref =~ s#\<1(\D(?:[^\>]|\>[^1])*)(?:\>1|ˇˇ)#\\uline\{$1\}#g;
    $$ref =~ s#\<3(\D(?:[^\>\n]|\>[^3])*?)(?:\>3|\n)#\\ensuremath\{\\widehat\{\\mbox\{$1\}\}\}#g;
    $$ref =~ s#\<4(\D(?:[^\>\n]|\>[^4])*?)(?:\>4|\n)#\\ensuremath\{\\underbrace\{\\mbox\{$1\}\}\}#g;
    $$ref =~ s#\<5(\D(?:[^\>\n]|\>[^5])*?)(?:\>5|\n)#\\ensuremath\{\\overbrace\{\\mbox\{$1\}\}\}#g;

    # undo the business with ~hit~...~
    $$ref =~ s#~[Hh]it~([^~]*)~#\\hit{$1}#g;

    # more could be done with < and >, but mark them with braces for now
    $$ref =~ s#\<\d*#\\\{#g;
    $$ref =~ s#\>\d*#\\\}#g;
    
    # Record separator
    $$ref =~ s#^\$\-?$#\$\\rule{0mm}{8mm}\n #g;
    
    # some punctuation
    $$ref =~ s#_#-#g if $self->{documentary};
    $$ref =~ s#_#\ --\ #g;

    # ibycus4 extras
    if ($self->{prosody})
    {
        $$ref =~ s#\%40#\\prosody{u}#g;
        $$ref =~ s#\%41#\\prosody{-}#g;
        $$ref =~ s#\%42#\\prosody{bu}#g;
        $$ref =~ s#\%43#\\prosody{a}#g;
        $$ref =~ s#\%44#\\prosody{a}#g;
        $$ref =~ s#\%45#\\prosody{au}#g;
        $$ref =~ s#\%46#\\prosody{b-}#g;
        $$ref =~ s#\%49#\\prosody{uuu}#g;
    }
    
    # protect ?'s and !'s in latin mode
    $$ref =~ s/([^\&]*)([^\$]*)/
                                        my $gk = (defined $1) ? $1 : '';
                                        my $lt = (defined $2) ? $2 : '';
                                        $lt =~ s#;#∑#g;         # protect ; : in latin mode
                                        $lt =~ s#:#µ#g;                 
                                        $lt =~ s#([?!])#$1\{\}$2#g;
                                        $gk.$lt;
                                        /gex;
    $$ref =~ s#s\?(?![\s])#\\d{s|}#g; # medial / final sigma doesn't much matter in frag. pap.
    $$ref =~ s#\!#\.#g;
        
    $$ref =~ s#[\&\$](?:4|14|24)([^\&\$\n]+)(?=[\&\$\n])#\\textrm\{\\ensuremath\{\^\{$1\}\}\}#g;
    $$ref =~ s#[\$\&](?:5|15|25)([^\&\$\n]+)(?=[\&\$\n])#\\textrm\{\\ensuremath\{\_\{$1\}\}\}#g;
        
    # $ (greek fonts)
    $$ref =~ s#\$(\d+)#\\fontfamily{ibycus}$gk_font[$1]\\selectfont{}#g;
    $$ref =~ s#\$\n#\\ngk{} #g;
    $$ref =~ s#\$#\\ngk{}#g;
        
    # & (roman fonts)
    $$ref =~ s#\&(\d+)#\\fontfamily{cmr}$rm_font[$1]\\selectfont{}#g;
    $$ref =~ s#\&\n#\\nrm{} #g;
    $$ref =~ s#\&#\\nrm{}#g;

    # % (more punctuation)
    $$ref =~ s#([a-zA-Z]['`|+)(=]*)%24#\\~\{$1\}#g;
    $$ref =~ s#([a-zA-Z]['`|+)(=]*)%25#\\c\{$1\}#g;
    $$ref =~ s#([a-zA-Z]['`|+)(=]*)%26#\\=\{$1\}#g;
    $$ref =~ s#([a-zA-Z]['`|+)(=]*)%27#\\u\{$1\}#g;
    $$ref =~ s#%80#{\\nrm\\itshape{v}}#g; #Diogenes of Oenoanda 
    $$ref =~ s#%(\d+)#$punct[$1]#g;
    # ? Underdot
    $$ref =~ s#([a-zA-Z]['`|+)(=]*)\?#\\d{$1}#g;
    $$ref =~ s#(['`|+)(=]+)\?#\\d{$1}#g;
    # Sigmas preceeding a \d for underdot wrongly become final
    $$ref =~ s#s\\d\{#s\|\\d\{#g;
    
    $$ref =~ s#%#\\dag{}#g;
    
    # @ (whitespace)
    $$ref =~ s#^([^a-zA-Z]*)@\d*#$1#g; # not when it's at the beginning
    $$ref =~ s#@\d+#\n#g; 
    $$ref =~ s#@#~~#g;
    $$ref =~ s#\ (?=\ )#~#g; # All spaces followed by another
    $$ref =~ s#\.\ #.~#g; # For abbrs.
    
    # ^
    $$ref =~ s#\^\d+#~~~~#g;
    
    # [] (brackets of all sorts)
    $$ref =~ s#\[(\d+)#$bra[$1]#g; 
    $$ref =~ s#\](\d+)#$ket[$1]#g;
    # [ and ] must be like this: {[} for latex
    $$ref =~ s#(\[+)#{$1}#g;
    $$ref =~ s#(\]+)#{$1}#g;
    
    # # (numerical symbols) this is obviously wrong
    $$ref =~ s/#508/\ --\ /g;
    #$$ref =~ s/[iI]tal¢([^¢]*)¢/\\emph{$1}/g;
    # get rid of those troublesome brackets around paragraphoi
    $$ref =~ s/\{\[\}\#6\{\]\}/\#6/g;
    $$ref =~ s/#(\d+)/$sym[$1]/g;  
    $$ref =~ s/#/\$\'\$/g;  
    
    # " (quotes)
    
    # Were the \textquotedblleft etc. forms necessary pre-ibycus4 ?
    #$$ref =~ s#([\s\n~])\"3\"3#$1\\textquotedblleft{}#g;
    $$ref =~ s#([\s\n~])\"3(\"3)?#$1`#g;
    #$$ref =~ s#\"3\"3#\\textquotedblright{}#g;
    $$ref =~ s#\"3(\"3)?#'#g;
    
    $$ref =~ s#\"1#$oddquotes[0]#g;
    $$ref =~ s#\"2#\\textrm{\\textquotedblleft}#g;
    $$ref =~ s#\"4#$oddquotes[1]#g;
    $$ref =~ s#\"5(?!\d)#\\textquoteleft{}#g;
    
    #$$ref =~ s#([\s\n~])\"6#$1<<#g; # Bug in ibycus? -- this used to work
    $$ref =~ s/([\s\n~])\"6/$1 $oddquotes[2]/g;
    $$ref =~ s/([\s\n~])\"7/$1 $oddquotes[3]/g;
    #$$ref =~ s#\"6#>>#g;
    $$ref =~ s#\"6#$oddquotes[4]#g;
    $$ref =~ s#\"7#$oddquotes[5]#g;
    
    $$ref =~ s#\"\d\d*#\\texttt{"}#g;
    #$$ref =~ s#([\s\n~])\"\d?#$1\\textquotedblleft{}#g;
    $$ref =~ s#([\s\n~])\"\d?#$1``#g;
    $$ref =~ s#\"\d?#''#g;
    $$ref =~ s#([\s\n~])\'#$1\`#g;
    
    # record separators
    if ($self->{latex_counter})
    {
        $$ref =~ s#xxbeginsamepage(?:\n\\nrm{} \n)?#\\begin{samepage}ˇˇcounter#g;
    }
    else
    {
        $$ref =~ s#xxbeginsamepage\n?#\\begin{samepage}#g;
    }
    $$ref =~ s#(?:ˇˇ)?ˇˇendsamepage\n+#\\end{samepage}\\nopagebreak[1]#g;
    $$ref =~ s#(?:ˇˇ)?ˇˇforcepagebreakˇˇˇˇ\n*#\\pagebreak[3]~\\\\#g;
    $$ref =~ s#∑#;#g;       # these were escaped above in Latin text
    $$ref =~ s#ø#:#g;               
    $$ref =~ s#µ#:#g;       
    $$ref =~ s#ˇßˇ#?#g;
    $$ref =~ s#sˇ£ˇ#$self->{ibycus4} ? 's\'' : 's\'\''#ge; # stop spurious final sigmas
    $$ref =~ s#ˇ£ˇ#$self->{ibycus4} ? '{\'}' : '\'\''#ge;
    $$ref =~ s#ˇ´ˇ#{#g;
    $$ref =~ s#ˇªˇ#}#g;
    $$ref =~ s#©#\\textrm{:}#g;
    #   You can eliminate some excess whitespace by commenting this next line out
    $$ref =~ s#\n\n+#~\\nopagebreak[4]\\\\~\\nopagebreak[4]\\\\#g; # consecutive newlines
    $$ref =~ s#\n\n#~\\nopagebreak[4]\\\\#g; # eol
    $$ref =~ s#\n#~\\nopagebreak[4]\\\\\n#g; # eol
    $$ref =~ s#ˇˇcounter#\\showcounter{}#g;
    # for early epigraphical orthography
    $$ref =~ s#([eo][)(]?)\=#\\~{$1}#g;
    $$ref =~ s#([)(]?[EO])\=#\\~{$1}#g;

}

# Here is the stuff for the beginning and ending of latex & html files

sub begin_boilerplate 
{
    my $self = shift;
    my ($size, $skip) = $self->{printer} ? (10, 12) : (17, 21);
    $size = $self->{latex_pointsize} if $self->{latex_pointsize};
    $skip = $self->{latex_baseskip} if $self->{latex_baseskip};
        
    my $begin_latex_boilerplate = "\\documentclass{article}";

    $begin_latex_boilerplate .= $self->{psibycus} ?
        "
\\usepackage{psibycus}" : $self->{ibycus4} ?  "
\\usepackage{ibycus4}"  : "
\\usepackage{ibygreek}" ; 
        
    $begin_latex_boilerplate .= $self->{ibycus4} ?
"
\\DeclareFontShape{OT1}{ibycus}{bx}{n}{%
   <5> <6> <7> <8> fibb848
   <9> fibb849
  <10> <10.95> <12> <14.40> <17.28> <20.74> <24.88> fibb84}{}" 
        : "
\\DeclareFontShape{OT1}{ibycus}{bx}{n}{%
   <5> <6> <7> <8> gribyb8
   <9> gribyb9
  <10> <10.95> <12> <14.40> <17.28> <20.74> <24.88> gribyb10}{}";

    $begin_latex_boilerplate .= $self->{psibycus} ? "
\\newcommand{\\hit}[1]{\\uline{#1}}\n"            : "
\\newcommand{\\hit}[1]{\\textbf{#1}}\n";

    $begin_latex_boilerplate .= "
\\renewcommand{\\familydefault}{ibycus}
\\newcommand{\\ngk}{\\normalfont\\fontfamily{ibycus}\\fontsize{$size}{$skip pt}\\selectfont}
\\newcommand{\\nrm}{\\normalfont\\fontfamily{cmr}\\fontsize{$size}{$skip pt}\\selectfont}
\\newcommand{\\dipleperi}{\\raisebox{-.8mm}{\\makebox[0pt][l]{\\hspace{1.3mm}.}}\\raisebox{2.5mm}{\\makebox[0pt][l]{\\hspace{1.3mm}.}}\\ensuremath{>}}
\\newcommand{\\marginlabel}[1]{\\mbox{}\\marginpar{\\raggedright\\hspace{0pt}{#1}}}
\\newcommand{\\titlebox}[2]{\\fbox{#1\\begin{minipage}{\\textwidth}\\begin{tabbing}#2\\end{tabbing}\\end{minipage}}\\rule[-8mm]{0mm}{8mm}}
\\usepackage{amssymb}
\\usepackage[latin1]{inputenc}
\\usepackage{ulem}\n";
        
    $begin_latex_boilerplate .= ($self->{printer}) ?  
'\\usepackage[nohead=true,twoside=false,top=20mm,left=10mm,bottom=5mm,right=10mm,marginpar=40mm,reversemp=true]{geometry}' 
        : 
'\\usepackage[paperheight=80cm,paperwidth=30cm,nohead=true,twoside=false,top=10mm,left=10mm,bottom=10mm,right=10mm,marginpar=40mm,reversemp=true]{geometry}';
        
    $begin_latex_boilerplate .= ($self->{prosody}) ?  
'\\DeclareFontFamily{OT1}{hpros}{\hyphenchar\font=-1}
\\DeclareFontShape{OT1}{hpros}{m}{n}{<-> hpros10}{}
\\newcommand{\prosody}[1]{{\fontfamily{hpros}\selectfont #1}}'
        : '';
        
    $begin_latex_boilerplate .=
"\n\\pagestyle{empty}
\\begin{document}
\\newcounter{resultno}\\setcounter{resultno}{1}
\\newcommand{\\showcounter}{\\marginlabel{{\\hfill\\bf {[}\\arabic{resultno}{]}}}\\addtocounter{resultno}{1}}
\\frenchspacing
\\reversemarginpar
\\normalem
\\begin{flushleft}
\\nrm{}\n";

    # HTML stuff -- but not used by CGI script, which generates its own headers

    my $charset = 'iso-8859-1';
    if ($self->{encoding} =~ m/UTF-?8|Unicode/i)
    {
        $charset = 'UTF-8';
    }
    elsif ($self->{encoding} =~ m/8859.?7/i)
    {
        $charset = 'ISO-8859-7';
    } 

        my $begin_html_boilerplate = << "END_HTML";
<HTML>
  <head>
    <meta http-equiv="charset" content="$charset">
        <title>Diogenes Result</title>
  </head>
  <body>

END_HTML

    my $font_spec = '<FONT FACE="'.$self->{unicode_font}.'">';

    print $begin_latex_boilerplate if $self->{output_format} =~ m/latex/;
    print $begin_html_boilerplate if $self->{output_format} =~ m/html/ 
	and not $Diogenes::cgi_flag;
    print $font_spec if $self->{output_format} =~ m/html/ and $self->{encoding} 
                    and $self->{unicode_font} 
                    and not $Diogenes::encoding{$self->{encoding}}{font_name}
                    and not $Diogenes::cgi_flag;
}
                
sub end_boilerplate
{
    my $self = shift;
    my $end_latex_boilerplate = "\\end{flushleft}\n\\end{document}\n";
    my $end_html_boilerplate =  '</body></HTML>';
        
    print $end_latex_boilerplate if $self->{output_format} eq 'latex';
    print '</FONT>' if $self->{output_format} =~ m/html/ and $self->{encoding} 
                       and $self->{unicode_font} 
                       and not $Diogenes::encoding{$self->{encoding}}{font_name};
    print $end_html_boilerplate if $self->{output_format} eq 'html';
        
}

sub simple_latex_boilerplate
{
    # Used eg. for generating gif of individual words in word list
    my $self = shift;
    my $bp = "\n\\documentclass[12pt]{article}";
    $bp .= $self->{ibycus4} ?
        "\\usepackage{ibycus4}" : 
        "\\usepackage{ibygreek}";
    $bp .="\\pagestyle{empty}
\\begin{document}
\\fontfamily{ibycus}\\fontsize{17}{21pt}\\selectfont\n";
    return $bp;
}

#sub strip_beta_formatting
#{#
#       my ($self, $ref) = @_;
 #   warn "$$ref\n";
#       $$ref =~ s/[\x01-\x06\x0e-\x1f\x80-\xff]+/\n/g ;
#       $$ref =~ s/\$//g;
#
#}

sub beta_encoding_to_external
{
    my ($self, $ref) = @_;
    my $encoding = $self->{encoding};
    # Beta code definitions
    my %alphabet = (
	A => 'alpha', B => 'beta', G => 'gamma', D => 'delta', 
	E => 'epsilon', Z => 'zeta', H => 'eta', Q => 'theta', I => 'iota', 
	K => 'kappa', L => 'lambda', M => 'mu', N => 'nu', C => 'xi', 
	O => 'omicron', P => 'pi', R => 'rho', S => 'sigma', T => 'tau', 
	U => 'upsilon', F => 'phi', X => 'chi', 
	Y => 'psi', W => 'omega', V => 'digamma', J => 'special' );
    # Note that rho can take breathings
    my %vowel = (A => 1, E => 1, I => 1, O => 1, U => 1, H => 1, W => 1, R => 1);
    my %other = (
	' ' => 'space', '-' => 'hyphen', ',' => 'comma',
	'.' => 'period', ':' => 'raised_dot', ';' => 'semicolon', '_' => 'dash',
	'!' => 'period', '\'' => 'apostrophe');
    # Chars (to search for) in encoding
    my $char = '[A-Z \'\-,.:;_!]';
    my $diacrits = '[)(|/\\\\=+123]*';
        
    if ($Diogenes::encoding{$encoding}{remap_ascii})
    {
        # These fonts cannot reliably be parsed as BETA code once the encoding
        # is done, so we might as well strip the junk out here
        $self->beta_formatting_to_ascii($ref);
    }

    # Lunate sigmas are ``obsolete'' according to the TLG BETA spec.
    $$ref =~ s#S3#S#g;
    # Force final sigmas. (watch out for things like mes<s>on, which shouldn't
    # become final -- I'm not sure that there's much one can do there)
    $$ref =~ s#(?<!\*)S(?![123A-Z)(|/\\=+\'])#S2#g; 
    
    if (ref $Diogenes::encoding{$encoding}{pre_match} eq 'CODE')
    {   # Code to execute before the match
	$Diogenes::encoding{$encoding}{pre_match}->($ref);
    }
    
    # For encodings close to BETA, we can do translation directly, by
    # giving a code ref, rather than a char map
    if (ref $Diogenes::encoding{$encoding}{sub} eq 'CODE')
    {       
	$Diogenes::encoding{$encoding}{sub}->($ref);
    }
    else
    {
	# This code uses the info in the Diogenes.map file to translate BETA
	# into an arbitrary Greek encoding.  All of this code is eval'ed at each
         # match of the regex, for each char with its diacrits:
	$$ref =~ s!(\*$diacrits)?($char)($diacrits)!
                                my ($a, $b, $c) = ($1, $2, $3);
                                if ($a and $c)
                                {       # Caps and trailing diacrits
                                        if        ($b eq 'S' and $c eq '2') { $c = ''; } # Oops. final sigma
                                        elsif ($c eq '|' ) { $a .= '|'; } # Iota "subscript" after a cap
                                        else  { warn "Unknown BETA code: $a$b$c"; }
                                }
                                my $code = $alphabet{$b} || '';
                                my $pre = '';
                                my $post = '';
                                if ($a and not $Diogenes::encoding{$encoding}{caps_with_diacrits})
                                {   # Magiscule (with leading diacrits for vowels as separate
                                        # glyphs in this encoding)
                                        $code =~ s/^(.)/\u$1/;
                                        if ($vowel{$b})
                                        {
                                                my @codes = ();
                                                $a =~ /\+/ and push @codes, 'diaer';
                                                ($a =~ /\)/ and push @codes, 'lenis') or
                                                ($a =~ /\(/ and push @codes, 'asper');
                                                ($a =~ /\// and push @codes, 'oxy') or
                                                ($a =~ /\\/ and push @codes, 'bary') or
                                                ($a =~ /\=/ and push @codes, 'peri');
                                                my $loner = join '_', @codes; 
                                                $pre = $Diogenes::encoding{$encoding}{$loner} || '';
                                                warn 'No mapping exists for BETA code '.
                                                        ($a||'').($b||'').($c||'')." in encoding $encoding.\n" 
                                                        if (not $pre) and (length $a > 1);
                                        }
                                }
                                elsif ($a)
                                {   # Magiscule (vowels combined with leading diacrits as 
                                        # fully-fledged, composite glyphs in this encoding)
                                        $code =~ s/^(.)/\u$1/;
                                        if ($vowel{$b})
                                        {
                                                $a =~ /\+/ and $code .= '_diaer';
                                                ($a =~ /\)/ and $code .= '_lenis') or
                                                ($a =~ /\(/ and $code .= '_asper');
                                                ($a =~ /\// and $code .= '_oxy')  or
                                                ($a =~ /\\/ and $code .= '_bary') or
                                                ($a =~ /\=/ and $code .= '_peri');
                                                $a =~ /\|/ and $code .= '_isub';
                                        }
                                }
                                elsif ($c and $vowel{$b})
                                {       # Miniscule vowels with (trailing) diacrits
                                        $c =~ /\+/ and $code .= '_diaer';
                                        ($c =~ /\)/ and $code .= '_lenis') or
                                        ($c =~ /\(/ and $code .= '_asper');
                                        ($c =~ /\// and $code .= '_oxy')  or
                                        ($c =~ /\\/ and $code .= '_bary') or
                                        ($c =~ /\=/ and $code .= '_peri');
                                        $c =~ /\|/ and $code .= '_isub';
                                }
                                elsif ($b eq 'S' and $c)
                                {
                                        ($c eq '2' and $code .= '_final') or
                                        ($c eq '3' and $code .= '_lunate');
                                } 
                                elsif ($c =~ m/^\d+$/)
                                {       # We've picked up some numbers spuriously (123, no S)
                                        $post = $b.$c;
                                }
                                $code = $other{$b} if $b and $other{$b}; 

                                $post = $Diogenes::encoding{$encoding}{$code} unless $post;
                                warn 'No mapping exists for BETA code '.
                                        ($a||'').($b||'').($c||'')." in encoding $encoding.\n" unless $post;
                                $post ? $pre.$post : $a.$b.$c;
                                !gex;
    }
        
    if (ref $Diogenes::encoding{$encoding}{post_match} eq 'CODE')
    {   # Code to execute after the match
        $Diogenes::encoding{$encoding}{post_match}->($ref);
    }

    if ($self->{output_format} eq 'html' and $Diogenes::encoding{$encoding}{font_name})
    {
        # Give browsers a hint -- converted to <FONT> tags later.
        $$ref = 'ˇˇ1' . $$ref . 'ˇˇ2';
    }
}

sub coptic_with_latin
{
        my ($self, $ref) = @_;
        $$ref =~ s/([^\&]*)([^\$]*)/
                                        my $cp = $1 || '';
                                        if ($cp)
                                        {
                                                $self->coptic_handler(\$cp);
                                        }
                                        my $lt = $2 || '';
                                        if ($lt)
                                        {
                                                $lt =~ s!\&(\d+)!\& $1!g; # horribleness
                                                $self->{latin_handler}->(\$lt);
                                        }
                                        $cp.$lt;
                                        /gex;
}
sub coptic_handler
{
    my ($self, $ref) = @_;
    my $encoding = $self->{coptic_encoding};
    
    return if $self->{coptic_encoding} eq 'beta';
    
    my %alphabet = ( A => 'alpha', B => 'beta', G => 'gamma', D => 'delta', 
            E => 'epsilon', Z => 'zeta', H => 'eta', Q => 'theta', I => 'iota', 
            K => 'kappa', L => 'lambda', M => 'mu', N => 'nu', C => 'xi', 
            O => 'omicron', P => 'pi', R => 'rho', S => 'sigma', T => 'tau', 
            U => 'upsilon', F => 'phi', X => 'chi', Y => 'psi', W => 'omega', V => 'digamma',
            s => 'shei', f => 'fei', h => 'hori', t => 'dei', j => 'gangia', g => 'shima');
    # Note that rho can take breathings
    my %other = (' ' => 'space', '-' => 'hyphen', ',' => 'comma',
            '.' => 'period', ':' => 'raised_dot', ';' => 'semicolon', '_' => 'dash',
            '!' => 'period', '\'' => 'apostrophe', '/' => 'forward_slash');
    # Chars (to search for) in encoding
    my $char = '[A-Z \'\-,.:;_!sfhtjg/]';
    my $diacrits = '[=+?]*';
    
if ($Diogenes::coptic_encoding{$encoding}{remap_ascii})
{
    # These fonts cannot reliably be parsed as BETA code once the encoding
    # is done, so we might as well strip the junk out here
    $self->beta_formatting_to_ascii($ref);
}

    if (ref $Diogenes::coptic_encoding{$encoding}{pre_match} eq 'CODE')
    {       # Code to execute before the match
        $Diogenes::coptic_encoding{$encoding}{pre_match}->($ref);
    }

    # For encodings close to BETA, we can do translation directly, by
    # giving a code ref, rather than a char map
    if (ref $Diogenes::coptic_encoding{$encoding}{sub} eq 'CODE')
    {       
        $Diogenes::coptic_encoding{$encoding}{sub}->($ref);
    }
    else
    {
            $$ref =~ s!(\\?)($char)($diacrits)!
                            my ($a, $b, $c) = ($1, $2, $3);
                            my $post = '';
                            my $code = $alphabet{$b} || '';
                            $code = $other{$b} if $b and $other{$b}; 
                            if ($b and $c)
                            {       # Miniscule vowels with (trailing) diacrits
                                    $c =~ /\+/ and $code .= '_diaer';
                                    $c =~ /\=/ and $code .= '_peri';
                            }
                            $post .= 'ÃÖ' if $a and $encoding =~ m/utf/i; # combining overline
                            $post .= $encoding =~ m/utf/i ? 'Ã£' : '?' if $c =~ m/\?/;
                            my $char = $Diogenes::coptic_encoding{$encoding}{$code} || '';
                            warn 'No mapping exists for BETA (Coptic) code '.
                                    ($a||'').($b||'').($c||'')." in encoding $encoding.\n" unless $char;
                            print STDERR ">>$char.$post\n";
                            $char.$post;
                            !gex;
    }
    
    if (ref $Diogenes::coptic_encoding{$encoding}{post_match} eq 'CODE')
    {   # Code to execute after the match
        $Diogenes::coptic_encoding{$encoding}{post_match}->($ref);
    }

    if ($self->{output_format} eq 'html' and $Diogenes::coptic_encoding{$encoding}{font_name})
    {
        # Give browsers a hint -- converted to <FONT> tags later.
        $$ref = 'ˇˇ1' . $$ref . 'ˇˇ2';
    }
}

# Bits and pieces

sub numerically { $a <=> $b; }

sub barf 
{
    my $self = shift;
    if ($self and $self->{dump_file})
    {
        use Data::Dumper;
        open DUMP, ">$self->{dump_file}" or die ("Can't open dump file");
        #print DUMP Data::Dumper->Dump ([$self], ['Diogenes']);
        print DUMP "\n\n#####################################################\n\n";
        print DUMP ${ $self->{buf} } if defined $self->{buf}; 
        close DUMP or die ("Can't close dump file");
    }
    croak shift;
}

##############################################
#--------------------------------------------#
#-------TLG Indexed (Word List) Search-------#
#--------------------------------------------#
##############################################

package Diogenes_indexed;
@Diogenes_indexed::ISA = ('Diogenes');

# The constructor is inherited.

sub read_index 
{
    my $self = shift;
    my $pattern = shift;
    $pattern = $self->simple_latin_to_beta ($pattern);
    my ($ref, @wlist) = $self->parse_word_list($pattern);
    
    $self->set_perseus_links; 
    
    if ($self->{filtered} or $self->{blacklist_file})
    {
        # If we are selecting texts, find out what words are in our texts.
        $self->parse_wcnts(@wlist);
        my @new_wlist;
        # Keep Greek alphabetical order.
        map {$self->{found_word}{$_} and push @new_wlist, $_} @wlist;
        $ref = $self->{word_total};
        @wlist = @new_wlist;
    }
    
    return $ref, @wlist;
}

# Override base class method
sub do_search 
{
    my $self = shift;
    
    $self->set_perseus_links; 
    
    $self->{pattern_list} = [];
    
    if ($self->{input_beta})
    {
        $self->{reject_pattern} = $self->beta_to_beta ($self->{reject_pattern});
    }
    elsif ($self->{input_raw})
    {
        $self->{reject_pattern} = quotemeta $self->{reject_pattern};
    }
    elsif (not $self->{input_pure})
    {
        $self->{reject_pattern} = $self->latin_to_beta($self->{reject_pattern});
    }
    
    print STDERR "Using reject pattern: $self->{reject_pattern}\n" if $self->{debug}
                                                         and $self->{reject_pattern};
    my @wlist = @_;
    $self->parse_wcnts(@wlist);
    $self->make_big_regexp;
    
    $self->begin_boilerplate;
    $self->do_word_search;
    $self->print_wlist_report;
    $self->end_boilerplate;
}

###############################################################################
#-----------------------------------------------------------------------------#
#---------------- Only private subs and methods below ------------------------#
#-----------------------------------------------------------------------------#
###############################################################################

###############################################################################
#                                                                             #
# Subroutine to calculate which blocks of the file tlgwlist.inx to            #
# search in, based upon the first two letters of the pattern (not counting    #
# diacritics, except for "'").  Eg. for the two letters AB, the first block   #
# to look in is the one indexed for AB, and the last is the one indexed AG.   #
# This leads to a certain amount of unneccessary searching, but it allows     #
# us to apply our regexp to a limited section of the large word list file.    #       
#                                                                             #
###############################################################################
sub parse_wlinx 
{
    my $self = shift;
        
    my ($pb_offset, $block);
    my ($pa_block, $pb_block) = (0, 0);
        
    # the order of the Greek alphabet in terms of its Roman representation in
    # BETA code ("'" is 1, who knows why?).
    my @gk = (2, 3, 16, 5, 6, 23, 4, 9, 11, 0, 12, 13, 14, 15, 17, 18, 10, 19, 20,
              21, 22, 7, 26, 24, 25, 8);                      
                        
    # A hash of the  Greek alphabet, each letter pointing to the next.
    my %incr = ('\'', 'A', 'A', 'B', 'B', 'G', 'G', 'D', 'D', 'E', 'E', 'Z', 'Z', 'H',
                'H', 'Q', 'Q', 'I', 'I', 'K', 'K', 'L', 'L', 'M', 'M',
                'N', 'N', 'C', 'C', 'O', 'O', 'P', 'P', 'R', 'R', 'S', 'S', 'T', 'T', 'U',
                'U', 'F', 'F', 'X', 'X', 'Y', 'Y', 'W', 'W', '\'');
        
    # get pattern, which should not include diacritics in its first two
    # letters, and make sure it is uppercase
    my $pattern = shift;
    # This input  must be at least 2 letters long 
    # (the index is indexed by the first 2 letters).
    $pattern =~ tr/a-z/A-Z/;
    die "Input pattern is not long enough (must be at least 2 letters).\n" 
        if $pattern =~ tr/A-Z'/A-Z'/ < 2;
    $pattern =~ tr/A-Z'//cd;
    print STDERR "pattern: $pattern\n" if $self->{debug};
    
    # @pa holds the first two letters of $pattern
    my @pa = (substr ($pattern, 0, 1), substr ($pattern, 1, 1));
        
    # generate starting offset
    my $pa_offset = ((($pa[0] eq '\'') ? 1 : $gk[(ord($pa[0]) - 65)]) - 1) * 27;
    $pa_offset += (ord($pa[1]) eq '\'') ? 1 : ($gk[(ord($pa[1]) - 65)]) + 1;

    # open the index to the word index and get the whole thing
    open WLINX, $self->{cdrom_dir}."$tlgwlinx" or 
        $self->barf("Could not open $self->{cdrom_dir}$tlgwlinx");
    binmode WLINX;
    local $/;
    undef $/;
    my $buf = <WLINX>;
    close WLINX or $self->barf("Couldn't close $tlgwlinx");

    # add up the cumulative data in the index to get block numbers for the
    # starting block.
    for (my $i = 0; $i < $pa_offset; $i++) 
    {
        $pa_block += ord (substr($buf, $i, 1));
    }
        
    # @pb gets the two letters in Greek alphabetical sequence after @pa 
    my @pb = @pa;

    # For some reason, degenerate cases in which one has impossible combinations 
    # of letters do not properly index to their imaginary place in the list.
    # Thus QH has many words, but QQ begins in the same block (681) as QH and
    # not where it should, which is in the block where QI starts -- where QQ
    # *would* be if there were any words that began with theta-theta.
    # So we have to keep incrementing letters until we find one that points to
    # a different block than the first set of letters.  This is wasteful and I
    # would regard it as a bug in the TLG index.
    while ($pb_block <= $pa_block) 
    {
        # `increment' the two letter string
        if ($pb[0] eq 'W' and $pb[1] eq 'W') 
        {   # end -- WW is the last two-letter group in the Greek alphabet
            last;
        }
        elsif ($pb[1] eq 'W') 
        {                               
            $pb[0] = $incr{$pb[0]};                 # eg. BW -> GA
            $pb[1] = 'A';                                           
        } 
        else 
        { 
            $pb[1] = $incr{$pb[1]};                 # the usual case: BB -> BG
        }
        
        # generate finishing offset
        $pb_offset = ((($pb[0] eq '\'') ? 1 : $gk[(ord($pb[0]) - 65)]) - 1) * 27;
        $pb_offset += (ord($pb[1]) eq '\'') ? 1 : ($gk[(ord($pb[1]) - 65)]) + 1;
        
        # add up the cumulative data in the index to get block numbers
        for (my $i = 0; $i < $pb_offset; $i++) 
        {
            $pb_block += ord (substr($buf, $i, 1));
        }
    }
    
    # return the starting and ending blocks between which to search
    print STDERR "@pa : @pb ;  $pa_block : $pb_block       \n" if $self->{debug};
    return ($pa_block, $pb_block);
}

#######################################################
#                                                     #
# Method to search the greek word-list for a pattern. #
#                                                     #
#######################################################
sub parse_word_list 
{       
    my $self = shift;
    my $pattern = shift;
    
    my ($buf, $block, $data, $word, $word_hits, $last_pos, $word_num);
    my ($before, $tally, $i);
    my (%words, @word_list);
    
    # get the parts of the file to search
    print STDERR "1>$pattern \n" if $self->{debug};
    
    # modify pattern to match diacritics before and after each letter
    $pattern =~ tr/a-z/A-Z/;
    my $original_pattern = $pattern;
    $pattern =~ s#([A-Z][\\\\\)\(]*)#$1\[\'\\\\\/\+\(\)\|\!\=\]\*#g;
    #$pattern =~ s#^#\['!]\*#g;
        
    print STDERR "2>$pattern \n" if $self->{debug};

    my $start_pat = 0;
    # h looks ahead for a rough breathing 
    $start_pat++ if $pattern =~ s#¨¨#(?=\\\(|[AEHIOWU/\\\\)=+?!|']+\\\()#gi;
    # non-rough breathing (possibly not at word beginning) 
    $pattern =~ s#¨£#(?!\\\(|[AEHIOWU/\\\\)=+?!|']+\\\()#gi;                
    $start_pat++ if $pattern =~ s#^\s+#(?<!['!A-Z)(/\\\\+=])#;
    $pattern =~ s#^#\['!A-Z)(/\\\\+=]\*#g unless $start_pat;
    $pattern =~ s#\s+$#(?!['!A-Z)(/\\\\+=])#;
        
    print STDERR "3>$pattern ($start_pat)\n" if $self->{debug};
        
    my ($start_block, $end_block);
    open WLIST, $self->{cdrom_dir}."$tlgwlist" or $self->barf("Couldn't open $tlgwlist");
    binmode WLIST;
    if ($self->{use_tlgwlinx})
    {   # Use the index to the word list, only looking at the bit of the word-list 
        # containing the first two letters of our word.
        ($start_block, $end_block) = $self->parse_wlinx($original_pattern);
        seek WLIST, ($start_block * 8192), 0 or $self->barf("Couldn't seek in $tlgwlist");
    }
    else
    {   # Just read in the whole thing
        $start_block = 0;
        $end_block = (-s WLIST) / 8192 + 1;
    }
    print STDERR "WL: $pattern \n" if $self->{debug};
    $tally = 0;
    for ($block = $start_block; $block <= $end_block; $block++) 
    {
        # read each block
        # Must not check for errors here, because often end-block is way
        # beyond the end of the file. -- Not sure why.
        read WLIST, $buf, 8192;
        $last_pos = 0;
        $word_num = 0;
                
        # look for the pattern, capturing it and the non-ascii count data
        # preceding it
        while ($buf =~ m#([\x80-\xff]+)($pattern[\x20-\x60\x7c]*)#g) 
        {
            $data = $1;
            $word = $2; 
            $tally++;
                        
#            print "block: ".(sprintf "%lx", $block)."\n";
#            print "pos: " . (sprintf "%lx", pos $buf) . "\n";
            # parse the non-ascii data
            for ($i = 0, $word_hits = 0; $i < length ($data); $i++) 
            {
#                print "data: ".(ord (substr($data, $i, 1))-128)."\n";
#                print "old: ".($word_hits << 7)."\n";
                $word_hits = ($word_hits << 7) + (ord (substr($data, $i, 1)) - 128);
#                print "hits: $word_hits\n";
            }
            print STDERR "$word: $word_hits\n\n" if $self->{debug};
                        
            # count the number of words between this and the previous hit (or
            # start of block to determine the word number within this block
            
            $before = substr ($buf, $last_pos, ((pos $buf) - $last_pos));
            $word_num++ while ($before =~ m#[\x80-\xff]+#go);
                        
            # store the important data: the word found, the count data, the
            # block in was found in and the number within that block
            push @word_list, $word;
            $words{$word} = $word_hits;
            push @{ $self->{word_list}{$word} }, ($word_hits, $block, $word_num);
            $last_pos = pos $buf;
        }
    }
    close WLIST or $self->barf("Couldn't close $tlgwlist");
        
    return \%words, @word_list;
}       

sub get_word_info 
{
    my ($self, $word) = @_;
    return @{ $self->{word_list}{$word} };
}

##########################################################################
#                                                                        #
# Method to calculate the authors and works in which a word found in the #
# word list is to be located.                                            #
#                                                                        #
##########################################################################
sub parse_wcnts 
{
    my $self = shift;
    my ($word, $first_byte, $serial_num, $next_byte, $word_count, $aw_data);
    my ($offset, $first_char, $second_char, $third_char, $junk, $entry_length);
    my ($total_count, $block_num, $word_num, $author_num, $work_num, $length);
    my ($entry, $buf ,$i);
    $self->{list_total} = 0;

    # get the words to use 
    my @words;
    if (@_ == 1 or not ref $_[0])
    {
        # A simple list of words
        map { warn ("Bad input in word list: $_") if ref $_ } @_[1 .. -1];
        $self->{check_word_stats} = 1;
        push @words, ref $_[0] ? @{ $_[0] } : @_;
        $self->{word_set}[0] = [@words];
        $self->{single_list} = 1;
    }
    else
    {
        # A list of lists of words
        my $j = 0;
        foreach my $x (@_)
        {
            next unless $x;
            warn ("Bad input in word list: $x") if ref $x and ref $x ne 'ARRAY';
            $self->{check_word_stats} = 0;
            # A simple word becomes a one-element list
            $x = [$x] unless ref $x;
            $self->{word_set}[$j++] = $x;
            push @words, @{ $x };
        }
        print STDERR "<p>Words: @{$self->{word_set}[0]}<p>\n" if $self->{debug};
        print STDERR "<p>Words: @{$self->{word_set}[1]}<p>\n" if $self->{debug};
        
    }
    $self->{check_word_stats} = 0 if $self->{reject_pattern};
    
    $self->{min_matches_int} = $self->{min_matches};
    $self->{min_matches_int} = 1 if $self->{min_matches} eq 'any';
    $self->{min_matches_int} =  scalar @{ $self->{word_set} } if 
        $self->{min_matches} eq 'all';

    print STDERR "MM: $self->{min_matches}\n" if $self->{debug};
    print STDERR "MMI: $self->{min_matches_int}\n" if $self->{debug};
    
    print STDERR Data::Dumper->Dump([$self->{word_set}]), "\n" if $self->{debug};  
    # open the index files
    open WCINX, $self->{cdrom_dir}."$tlgwcinx" or $self->barf("Couldn't open $tlgwcinx");
    binmode WCINX;
    open WCNTS, $self->{cdrom_dir}."$tlgwcnts" or $self->barf("Couldn't open $tlgwcnts");
    binmode WCNTS;
    open AWLST, $self->{cdrom_dir}."$tlgawlst" or $self->barf("Couldn't open $tlgawlst");
    binmode AWLST;
    
    # We may want to blacklist some authors
    my $blacklist = '';
    if ($self->{blacklist_file})
    {
        open BL, "<$self->{blacklist_file}" or 
            die "Couldn't open blacklist file: $self->{blacklist_file}: $!\n";
        {
            local $/;
            undef $/;
            $blacklist = <BL>;
        }
    }
    
    my ($current_block, $current_word_num) = (-1, -1);
    # iterate through the list
    foreach $word (@words) 
    {
        # get the info for this word
        ($total_count, $block_num, $word_num) = @{ $self->{word_list}{$word} };
        
        # Skip if we already have the info stored.
        next if $self->{found_word}{$word};
        return if $Diogenes_Daemon::flag and not print ("\0");
        
        # An important optimization is to check to see if this is the next word in the
        # current block, in which case, we just read the next record.  If you feed back
        # the words to this routine in the same order in which they were output, this will
        # generally be the case.  If not, we have to reseek to the start of the block and 
        # reparse the file up to the word number.
        
        print STDERR ">> $block_num: $word_num ($word)\n" if $self->{debug};
        print STDERR "|| $current_block: $current_word_num\n\n" if $self->{debug};
        unless ($block_num == $current_block and $word_num == $current_word_num + 1)
        {
            # get the offset data (based on the block number in the word list)
            seek WCINX, ($block_num * 4), 0 or $self->barf("Couldn't seek in $tlgwcinx");
            read WCINX, $offset, 4 or $self->barf("Couldn't read from $tlgwcinx");
            
            # the offset data (32 bits) is big-endian 
            $offset = unpack "N", $offset;
            
            # seek in the big nasty file with all the data to the offset for our
            # block
            seek WCNTS, $offset, 0 or $self->barf("Couldn't seek in $tlgwcnts");
            $current_block = $block_num;
            
            # we now must read every entry in this section of the file (the only one
            # which is not itself broken into 8k blocks, unfortunately) beacuse the
            # entries are of variable length and apparently are not indexed, until we 
            # come to our word
            
        
            for ($i = 1; $i < $word_num; $i++) 
            {
                print STDERR "] $offset: $i ($word)\n" if $self->{debug};
                # ignore `word form byte' (whatever that is)
                read WCNTS, $junk, 1 or $self->barf("Couldn't read from $tlgwcnts");
                
                # the next byte(s) give the length of this entry (which we want to
                # skip)
                read WCNTS, $length, 1 or $self->barf("Couldn't read from $tlgwcnts");
                $entry_length = ord ($length); 
                if ($entry_length & hex("80")) 
                {
                    read WCNTS, $next_byte, 1 or 
                        $self->barf("Couldn't read from $tlgwcnts");
                    $entry_length = (($entry_length & hex("7f")) << 8 ) + 
                        ord ($next_byte);
                }
                                
                # now we seek past the rest of this entry
                seek WCNTS, $entry_length, 1 or 
                    $self->barf("Couldn't seek through $tlgwcnts");
            }
        }
        $current_word_num = $word_num;
        $self->{word_total}{$word} = 0;
        
        # We should now be at the entry we are interested in
                
        # ignore `word form byte'
        read WCNTS, $junk, 1 or $self->barf("Couldn't read from $tlgwcnts"); 
        # the next byte(s) give the length of our entry 
        read WCNTS, $length, 1 or $self->barf("Couldn't read from $tlgwcnts");
        $entry_length = ord ($length);
        if ($entry_length & hex("80")) 
        {
            read WCNTS, $next_byte, 1 or $self->barf("Couldn't read from $tlgwcnts");
            $entry_length = (($entry_length & hex("7f")) << 8 ) + 
                ord ($next_byte);
        }
        # read the rest of the entry into $buf and close the file
        read WCNTS, $buf, $entry_length or $self->barf("Couldn't read from $tlgwcnts");
                
        # go back to the start of the index of authors and works
        seek AWLST, 0, 0 or $self->barf("Couldn't seek to the start of $tlgawlst");
        
        my $entry = 0;          # An index for the entries in the author/work file.
        my $running_count = 0;  # We add the number of hits reported for each work
        # and compare this total against the total
        # reported in the word list. 
        my $i = -1;                             # This is an index into $buf
      ENTRY:  
        while ($i < $entry_length - 1) 
        {
            # first we get a serial code number which is a pointer to a (cumulative)
            # offset within another file (tlgawlst.inx) that encodes the author/work
            # combinations 
                        
            $first_byte = substr ($buf, ++$i, 1);
            $serial_num = ord ($first_byte);
            if ($serial_num & hex("80")) 
            {
                $next_byte = substr ($buf, ++$i, 1);
                $serial_num = (($serial_num & hex("7c")) << 6 ) + ord ($next_byte);
            }
            else 
            {
                $serial_num = $serial_num >> 2;
            }
            
            # now we get the number of times our word is found in the
            # author/work combination under present consideration
                        
            $word_count = ord ($first_byte) & hex("03");
            if ($word_count == 0) 
            {
                $word_count = substr ($buf, ++$i, 1);
                $word_count = ord ($word_count);
                if  ($word_count & hex("80")) 
                {
                    $next_byte = substr ($buf, ++$i, 1);
                    $word_count = (($word_count - hex("80")) << 8 ) + 
                        ord ($next_byte);
                }
                elsif ($word_count == 0) 
                {
                    $word_count = substr ($buf, ++$i, 1);
                    $next_byte = substr ($buf, ++$i, 1);
                    $word_count = ((ord ($word_count)) << 8) + ord ($next_byte);
                }
            }
            
                
            # the serial numbers begin from 1, not 0.  If the serial num is 1,
            # then it indicates the next work of this author -- we want that
            # to go to 0, so that we don't seek forward and skip anything at all, 
            # and the next read will just get the next 3 bytes in tlgawlst.inx.
            $serial_num = $serial_num - 1;
            print STDERR "Serial Num: $serial_num; " if $self->{debug};
            
            # each record in tlgawlst.inx, the file containing a sequential list
            # of the codes for each author/work combination in the TLG is three 
            # bytes long
            $offset = (3 * $serial_num);
            
            # the offset is cumulative; we go forward in the file relative to the
            # last author/work combination in which our word was found
            seek AWLST, $offset, 1 or $self->barf("Couldn't seek in $tlgawlst");
            read AWLST, $aw_data, 3 or $self->barf("Couldn't read from $tlgawlst");
                        
            # decode the three bytes to yield the author number, work number and
            # the number of times our word is found within that work.
            # The first byte gives the more significant bits ( > 6) of the author number;
            # the second byte contains the lower six bits of the author
            # number, and its two low bits are the more significant bits 
            # of the work number, whose low byte is the third byte.
            $first_char = ord (substr ($aw_data, 0, 1));
            $second_char = ord (substr ($aw_data, 1, 1));
            $third_char = ord (substr ($aw_data, 2, 1));
            $author_num = ($first_char << 6) + ($second_char >> 2);
            $work_num = (($second_char & hex("03")) << 8) + $third_char;
            
            $author_num = sprintf '%04d', $author_num;
            $work_num = sprintf '%03d', $work_num;
            
            print STDERR "Auth: $author_num; Work: $work_num; Word: $word; Word count: $word_count\n" if $self->{debug};
                
            # keep a running total, to make sure that we find all of the instances
            # that we should.
            $running_count += $word_count;
            $entry++;
            
            # Skip if we are selecting texts and this one was not chosen.
            next ENTRY if $self->{filtered} and 
                not ($self->{req_authors}{$author_num} 
                     or $self->{req_auth_wk}{$author_num}{$work_num} );
            if ($blacklist)
            {
                if ($blacklist =~ m/$self->{tlg_file_prefix}$author_num/i)
                {
                    print STDERR "Skipping blacklisted author: $author_num\n" if 
                        $self->{debug};
                    next ENTRY;
                }
            }
                        
            $self->{word_counts}{$author_num}{$work_num}{$word} = $word_count;
            $self->{word_total}{$word} += $word_count;
            $self->{found_word}{$word} = 1;
            # using this for testing ...
            $self->{temp_var}{$word}{$author_num} = 1;
        }
        if ($running_count != $total_count) 
        {
            # if the totals don't jibe, halt
            if ($word eq 'KAI/')
            {
                warn("\nWord-list totals don't agree for $word: this is a known error.\n");
            }
            else
            {
                warn( 
#                       $self->barf( 
"\n\n#########################################################################\n".
"ERROR: For the word $word ". 
"The total count in the word list is $total_count, ".
"but I only see $running_count in $tlgwcnts.\n\n".
"Please send a copy of ".
"this error message to the author of the program.\n".
"Diogenes version ($Diogenes::Version).".
"\n#########################################################################\n\n");
            }
        }
    } # end of the iteration for each word
    continue
    {
        # Add the total of words selected form list
        $self->{list_total}     += $self->{word_total}{$word};
    }

    close AWLST or $self->barf("Couldn't close $tlgawlst");
    close WCNTS or $self->barf("Couldn't close $tlgwcnts");
    close WCINX or $self->barf("Couldn't close $tlgwcinx");
        
    print STDERR Data::Dumper->Dump([$self->{word_counts}], ['word_counts']) if $self->{debug};
    # return the number of works in which the word was found (went one too
    # far)
    return --$entry;
}

sub make_big_regexp
{
    my $self = shift;
    # Construct the mammoth regexps to test for all patterns in each set, in
    # descending order of length.   
    
    foreach my $set (@{ $self->{word_set} })
    {
        my $pattern = $Diogenes::lookback;
        foreach my $word (sort {length $b <=> length $a } @{ $set })
        {       
            # Skip if word was not found in the selected texts
            next unless $self->{found_word}{$word};
            my ($lw, $w) = $self->make_tlg_regexp ($word);
            $self->{tlg_regexps}{$word} = $lw;
            $pattern .= '(?:' . $w . ')|';
        }
        chop $pattern;
        print STDERR "Big pattern: $pattern \n" if $self->{debug};
        push @{ $self->{pattern_list} }, $pattern;
        
    }
}

# $lookback is used globally in order to exclude bits with preceding word
# elements any hyphenation, and to catch leading accents and asterisks (prefix
# must not be used globally, for it causes a major efficiency hit).  Revised to
# skip such things as PERI- @1 BALLO/MENOS (0007, 041).  Watch out for
# PROS3BA/LLEIN.

# This is a sadly ad hoc procedure, which will not help us with eliminating
# SUM-˛ÔÄ∞∞∏∂ˇÔÅ∞±¥ˇÔÇ»¡ˇúÑ°·àûBAI/NEI (0086, 014) across blocks.
# When Perl has variable-length, zero-width lookbehind, we will be able to fix this.
# Had to remove (?<![!\]]), as it improperly rejects some words.

my $usedch = '\\x27-\\x29\\x2f\\x3d\\x41-\\x5a\\x7c';


# This is the RIGHT line:
#$Diogenes::lookback = '(?<!S\d)(?<!\-\ [@"]\d\ [\\x80-\\xff])(?<!\-[\\x80-\\xff][@"]\d)(?<!\-[\\x80-\\xff][@"])(?<!\-[\\x80-\\xff][\\x80-\\xff])(?<!\-[\\x80-\\xff])(?<!['.$usedch.']\\*)(?<!['.$usedch.'])';
# This is the workaround for the TLG disk e hyphenation bug:
$Diogenes::lookback = '(?<!S\d)(?<!\-\ [@"]\d\ [\\x80-\\xff])(?<!\-[\\x80-\\xff][\\x80-\\xff])(?<!\-[\\x80-\\xff])(?<!['.$usedch.']\\*)(?<!['.$usedch.'])';
###############################################################
#                                                             #
# Method to generate a regular expression that corresponds to #
# the TLG word list's definition of a `word' from the word as #
# it appears in the word-list.                                #
#                                                             #
###############################################################


sub make_tlg_regexp 
{
    my ($self, $word, $not_begin, $not_end) = @_;
    # $not_begin and $not_end inhibit search for word-boundaries, front and end.
        
    my ($front, $sep, $back);
    my $diacrits = '\/\\\\\=\+\?\!\)\(\|\'';
        
    # Copy args if passed, otherwise assume full word with boundaries
    my $begin = $not_begin ? 1 : 0;
    my $end   = $not_end   ? 1 : 0;
                                
    my $vow = 'AEHIOWU';
    my $cons = 'BCDFGKLMNPQRSTVXYZ';

    # These are the bytes which do not appear in the word list. I (added "/"),
    # because of the bug shown by BRUXW/O(/)MENOS in 5014.  This, however,
    # produces many false positives where the word is meant to have no accent.
    # Added also "(" and ")", because there are sometimes breathings mid-word.
    # Added apostrophe as well.  Removed / and addressed the problem below. 
    # Removed space and \ 
    my $unused =
'\\x02-\\x19\\x22-\\x27\\x28-\\x2e\\x30-\\x3c\\x3e-\\x40\\x5b\\x5d-\\x7b\\x7d-\\xff';
    # these are the characters used in the word list
    my $used = '\\x21\\x27-\\x29\\x2f\\x3d\\x41-\\x5a\\x7c';
    my $unused_plus_space =
'\\x02-\\x20\\x22-\\x27\\x28-\\x2e\\x30-\\x3c\\x3e-\\x40\\x5b\\x5d-\\x7b\\x7d-\\xff';

    $word = quotemeta $word;
    $word =~ s/(?:\\\s)+/ /g;               # other spaces (not at start or end)
    print STDERR "Quotemeta: $word \n\n" if $self->{debug};

    # Unfortunately, early works in the corpus like Euripides have things like 
    # *)AMAZO/- ^250{[STR.} .^63NWN for *)AMAZO/NWN.
    # We make allowance first for hyphenation, with line breaks and block breaks
    # in between.  We then allow for anything else intervening between any two
    # letters: formatting codes, etc. 
    # This part of the regexp is the primary cause of the program's slowness.
    # Must allow for BA?- ...SKOPAI/, with ? before the hyphenation.
    # Also Latin strings: eg. A)NAI/- ^288{&Str. 2.$} .^63DEIAN
        
    # We allow for anything to intervene after a -, until there us a $used letter.
    # this didn't work for the Euripides example above
    #my $mid_word = "[?+]?(?:\-(?:[\\x00-\\xff](?![$used])|(?:\&[^\$]+))*[\\x00-\\xff])?[$unused]*";
    #Instead, we allow any non-binary data between a hyphen and some binary
    #Why did I abandon this solution earlier?
    my $mid_word = "[?+]?(?:\-(?:[\\x01-\\x7f]*[\\x00\\x80-\\xff]+))?[$unused]*";
                        
    # permit non-(alphabetic & diacritical) bytes to intervene
    $word =~ s#([$used])(?!$)#$1$mid_word#g;
    # spaces between words
    $word =~ s# (?!$)# [$unused_plus_space]*#g;
    print STDERR "Mid-word: $word\n\n" if $self->{debug};
    
    # ! (papyrus dot) at beginning or end is often ] or [ in the
    # texts, in which case we know that that is where the `word'
    # ends. v.9: added dot "." for tlg e
    my $front_dot = '[\!\]\.]+';
    $begin++ if $word =~ s#^(?:\\\!)#$front_dot#;
    #$begin++ if $word =~ s#^(?:\\\!)#\[\\!\\\]\\.\]\+#;
    # This is the RIGHT line:
    #$end++ if $word =~ s#(?:\\\!)$#\[\\!\\\[\\.\]#;
    # This is a workaround for TLG E hyphenation bug:
    # allow a word ending in ! to end at a hyphenation and a quote on the new line
    $end++ if $word =~ s#(?:\\\!)$#(?:\[\\!\\\[\\.\]|-(?=[\\d\\x80-\\xff\\x00]*\")|-(?=[_ .!\\]\\d\\x80-\\xff\\x00]*\\\]))#;
    print STDERR "!: $word\n\n" if $self->{debug};
                                
    # allow for capitalized words with diacritics moved in front
    $word =~
#               s#^([AEHIOWUR])\Q$mid_word\E(\\(?:\)|\())\Q$mid_word\E([\\\/=+|]*)#\(\?\:$1$2$3\|\\\*$2$3$1\)$mid_word#;
#               s#(^(?:\Q$front_dot\E)?(?:\Q$mid_word\E)?)([AEHIOWUR])\Q$mid_word\E(\\(?:\)|\())\Q$mid_word\E([\\\/=+|]*)#\(\?\:$1$2$3$4\|$1\\\*$3$4$2\)$mid_word#;
        s#(\b(?:\Q$front_dot\E)?(?:\Q$mid_word\E)?)([AEHIOWUR])\Q$mid_word\E(\\(?:\)|\())\Q$mid_word\E([\\\/=+|]*)#\(\?\:$1$2$3$4\|$1\\\*$3$4$2\)$mid_word#;
                                
    ##################################################################
    #                                                                #
    #  let oxytone accent become barytone:                           #
    # $word =~ s#\\\/$#\[\\/\\\\\]# or                               #
    #                $word =~ s#\\\/([^AEHIOWU]+)$#\[\\/\\\\\]$1#;   #
    #  The above would be more grammatical, but the TLG converts all #
    #  grave accents in the text to acute in the index, even when    #
    #  they are not on the final syllable, as in pseuo-word          #
    #  artifacts like KATALHKTIKO/NON, from KATALHK-TIKO\N[1O/N]1    #
    #  in 5014, 007.                                                 #
    #                                                                #
    ##################################################################
    $word =~ s#\\\/#\[\\/\\\\\]#g;
                        
    # allow for r)r( mid-word.
    $word =~ s#\*R#\*R\[\\(\\)]\?#g;
    print STDERR "rr: $word\n\n" if $self->{debug};
                                
                                
    #############################################################################
    #                                                                           #
    #  allow for accents thrown back from following enclitic                    #
    # if ($word_key =~ m#\/[\|$cons]*[$vow]+[$cons]*[$vow]+[$cons]*$            #
    #                        or $word_key =~ m#\=[\|$cons]*[$vow]+[$cons]*$#) { #
    #        # proparoxytone or properispomenon                                 #
    #        $word =~ s#(.*[$vow])#$1\\/?                                       #
    # }                                                                         #
    #  The above is the grammatically correct answer, but it fails              #
    #  in some cases, since apparently the TLG word list simply                 #
    #  strips the second accent from a `word', even from something              #
    #  like BRUXW/<6O/>6MENOS, where the second accent is really a              #
    #  variant, thus giving BRUXW/OMENOS in the word list.                      #
    #  So instead we allow any accent after any vowel after the                 #
    #  first accent (/=) in the word list entry.                                #
    #                                                                           #
    #############################################################################
                                
    $word =~ m#(.*)()#;
    $word =~ m#([^=/]*\\[=/])(.*)#;
    ($front, $back) = ($1, $2);
    print STDERR "Front: $front\nBack: $back\n\n" if $self->{debug};
    $back =~ s#([$vow])#$1\[\\=\\/\\\\\]?#g;
    $word = $front.$back;
    
# End of the regexp -- it is nearly the same as $used, except with the hyphen
# and with * added. We use a lookahead assertion, so that we don't step on the
# next search (in the case of *BRO/MIE *BRO/MIE, ktl.) We cannot end on a "*".
# We also allow ( because of words like A)GKONI/WAI( and KATANEU=AI( and we
# allow ) because of words like A)GLAI+ZE'QW), and diallow lower-case Latin so
# that the first letter of Anon. is not counted as an Alpha. If the pattern
# ends in a !, then we allow that.                        

# Added ] [ + and \ to the second group; had to delete + and ] and [
# We must allow AAA! before any word.

## For Disk E, we have to match A)POLOGHSAMEN!N, so allow anything to follow a final dot in the pattern
##      $end ?
##              $word =~
##              s/$/(?![\\x27\\x2a\\x2d\\x2f\\x3d\\x41-\\x5a\\x61-\\x7a\\x7c])/
##      :       $word =~
##              s/$/(?![\\x21\\x27\\x2a\\x2d\\x2f\\x3d\\x41-\\x5a\\x5c\\x61-\\x7a\\x7c])/;

    unless ($end)
    {
        $word =~
            s/$/(?![\\x21\\x27\\x2a\\x2d\\x2f\\x3d\\x41-\\x5a\\x5c\\x61-\\x7a\\x7c])/;
    }       
    my $full_word = $begin ? $word : $Diogenes::lookback.$word;
    
    $word =~ s#^#\\*?#; # To catch leading capitalization
    
    # The first, longer regexp includes the lookback stuff that comes before
    # the word; the shorter one is for inclusion in a larger, compound regexp
    return ($full_word, $word);
}

########################################################################
# Method to do the actual search, using the data that has been gleaned #
# from the TLG word list by other methods.                             #
########################################################################

sub do_word_search 
{
    my $self = shift;
    my ($author, $word, $work, $word_key, $author_num, $start_block, $end_block);
    my ($filename, $offset, $bare_word);
    
    local $/;
    undef $/;
    my $buf;
    $self->{buf} = \$buf;
        
    # Loop through each author in which one or more of our words were found
    # (according to the word list)
    foreach $author (sort numerically keys %{ $self->{word_counts} }) 
    {
        $filename = $self->{file_prefix} . $author;
        
        # open the .txt file 
        open INP, "$self->{cdrom_dir}$filename$self->{txt_suffix}" 
            or $self->barf("Couln't open $filename$self->{txt_suffix}!");
        binmode INP;
        
        # loop through each work in which a match was found
      WORK:   foreach $work (sort keys %{ $self->{word_counts}{$author} }) 
      {
          my %counts = ();
          unless ($self->{single_list})
          {
              # Loop over the contents of each set, adding up hits in this work
              foreach my $set_num (0 .. $#{ $self->{word_set} })
              {
                  local $^W = 0; # no warnings for patterns not in this work
                  $counts{$set_num} += $self->{word_counts}{$author}{$work}{$_} 
                  for @{ $self->{word_set}[$set_num] };
              }
              print STDERR ((join ', ', values %counts), " | ") if $self->{debug};
              my $sets = grep { $_ > 0 } (values %counts);
              #print ">$sets\n";
              
              # Skip this work if a match is impossible here
              next WORK unless $sets >= $self->{min_matches_int};
          }
          # /Now/ parse .idt file
          $self->parse_idt($author);
          
          # get only those blocks of the file containing the work in question
          $start_block = $Diogenes::work_start_block{$self->{type}}{$author}{$work};
          $offset = $start_block << 13;
          seek INP, $offset, 0;
          if ($work == $Diogenes::last_work{$self->{type}}{$author})
          {
              $buf = <INP>;
              print STDERR "\nReading from $offset to the end of $filename.txt!\n" if $self->{debug};
              $self->barf ("Couln't read the rest of $filename!") unless
                  defined $buf;
          }
          else
          {
              # Subtle stringification wierdness here to make the 
              # automagic increment work right 
              my $next = "$work"; 
              ++$next;
              ++$next until 
                  exists ($Diogenes::work_start_block{$self->{type}}{$author}{$next});
              $end_block = $Diogenes::work_start_block{$self->{type}}{$author}{$next};
              print STDERR "\nReading from $offset to ", $end_block << 13, 
                  " of $filename.txt!\n" if $self->{debug};
              read INP, $buf, (($end_block - $start_block + 1) << 13) or
                  $self->barf ("Couln't read from $filename");
          }
                                                
          my @order;
          if ($self->{single_list})
          {
              @order = (0);
              $counts{0}++;
          }
          else
          {
              # Optimal searching order for sets within this work
              @order = sort { $counts{$a} <=> $counts{$b} } keys %counts;
              
              # Cut off needless sets at top end of list
              $#order = @{ $self->{word_set} } - $self->{min_matches_int};
          }
          foreach my $set_num (@order)
          {
              # Skip this set if there are no hits in it for this work
              next unless $counts{$set_num};
              
              foreach my $word_key (@{ $self->{word_set}[$set_num] })
              {
                  next unless $self->{word_counts}{$author}{$work}{$word_key};
                  print STDERR 
                      "\nSearching in $Diogenes::author{$self->{type}}{$author}, ", 
                      "$Diogenes::work{$self->{type}}{$author}{$work} for $word_key \n" if
                      $self->{debug};
                  $self->{word_key} = $word_key;
                  print STDERR "\nWord list entry: $word_key\n" if $self->{debug};
                  
                  # use in the form of a suitable regexp
                  $word = $self->{tlg_regexps}{$word_key};
                  print STDERR "Using pattern: $word in author $author\n\n" if 
                      $self->{debug};
                  # clear the last search
                  undef $self->{seen}{$author};
                  
                  return if $Diogenes_Daemon::flag and not print ("\0");
                                        
                  # this does the search, storing the locations in %seen
                  while ($buf =~ m#$word#g)
                  {
                      push @{ $self->{seen}{$author} }, (pos $buf);
                  }
                  
                  print STDERR "Seen: " . @{ $self->{seen}{$author} }. "\n" if 
                      $self->{seen}{$author} and $self->{debug};
                  # print the hits, after finding location and context
                  $self->{current_work} = $work;
                  $self->extract_hits($author);
                  if ($self->{check_word_stats} 
                      and $self->{word_counts}{$author}{$work}{$word_key} >
                      ($self->{hits_hash}{$author}{$work}{$word_key} || 0) )
                  {
                      # We have a false negative.  
                      if ($author eq '2892' and $work eq '110')
                      {   # Maximus Confessor
                          warn 
                              "Word list counts are off for author $author, work $work. ".
                              "This is a known error.\n\n";
                      }
                      else
                      {
                          warn (
"\n\n+-----------------------------------------------------------+\n".
        "ERROR: The TLG word list indicates that there ".
        "should be $self->{word_counts}{$author}{$work}{$word_key} instance(s)\n".
        "of the word $word_key for author number $author, work number $work, but \n".
        "Diogenes found " . ( $self->{hits_hash}{$author}{$work}{$word_key} || 0 ) .
        " of them.\n\n".
        "Please send a copy of ".
        "this error message to $Diogenes::my_address.\n".
        "Diogenes version ($Diogenes::Version).".
        "\n+-----------------------------------------------------------+\n\n");
                      }
                  }
                  elsif ($self->{check_word_stats} 
                         and $self->{word_counts}{$author}{$work}{$word_key} <
                         $self->{hits_hash}{$author}{$work}{$word_key}) 
                  {
                      # We have one or more false positives.  
                      if ($word eq 'KAI/')
                      {
                          warn(
                              "\nWord-list totals don't agree for $word: ".
                              "this is a known error.\n");
                      }
                      else
                      {
                          my $inst = ($self->{hits_hash}{$author}{$work}{$word_key} -
                                      $self->{word_counts}{$author}{$work}{$word_key});
                          warn (
                              "WARNING: Diogenes found $inst extra instance".
                              ($inst == 1 ? '' : 's').
                              " of $word_key in author $author, work $work. \n");
                      }
                  }
              }
          }
      }
        close INP or $self->barf("Couln't close $filename!");
    }       
}


# Uninteresting debugging subroutine
sub print_word_search 
{
    my $self = shift;
    my $total = 0;
        
    my ($author, $word, $work);
        
    # This stuff is mostly for debugging
    foreach $author (sort numerically keys %{ $self->{word_counts} }) 
    {
        print STDERR "------------------------------ \n\n" if $self->{debug};
        print STDERR "author: $author \n" if $self->{debug};
        foreach $work (sort numerically keys %{ $self->{word_counts}{$author} }) 
        {
            foreach $word (sort keys %{ $self->{word_counts}{$author}{$work} }) 
            {
                print STDERR "word: $word \n" if $self->{debug};
                $total += $self->{word_counts}{$author}{$work}{$word};
                print STDERR "work: $work --> word count: $self->{word_counts}{$author}{$work}{$word} \n\n" if $self->{debug};
            }
        }
    }
    print "\n##########\n";
    print "Total instances reported by word list: $total\n";
    print "Total hits: $self->{hits}\n";
    print "##########\n\n";
}

#####################################################################
#                                                                   #
# Method to print the overall results of a word-list search.        #
# It's expected that Diogenes may find more matches than            #
# anticipated, since it values comprehensiveness over selectivity.  #
#                                                                   #
#####################################################################
sub print_wlist_report 
{
    my $self = shift;

    my $output = "\&\nIncidence of all words as reported by word list: ";
    $output .= $self->{list_total} || 0;
    $output .= "\nPassages containing those words reported by Diogenes: ";
    $output .= $self->{hits} || 0;
    $output .= "\n\n";
    $output .= "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n" 
        unless $self->{output_format} eq 'html';
    $self->print_output(\$output);
        
}

sub numerically { $a <=> $b; }


#############################################
#-------------------------------------------#
#---------------File Browser----------------#
#-------------------------------------------#
#############################################
package Diogenes_browser;
@Diogenes_browser::ISA = qw( Diogenes );

# Method to print the authors whose names match the pattern passed as an    #
# argument.                                                                 #

sub browse_authors 
{
    my ($self, $pattern) = @_;
    $self->{latex_counter} = 0;
    return (1 => 'doccan1', 2 => 'doccan2') if $self->{type} eq 'bib';
    return %{ $self->match_authtab($pattern) }; 
}

# Method to print the works belonging to the specified author (number).     #

sub browse_works 
{
    my $self = shift;
    my $auth_num = shift;
    my $work_num;
    # The real auth num is actually not a number for civ texts, so
    # we get it here (conversely, tlg bibliography files have a real author
    # number, such as 9999, that is not reflected in the file name)
    my $real_num = $self->parse_idt ($auth_num);
    #return %{ $Diogenes::work{$self->{type}}{$real_num} };
    my %ret =  %{ $Diogenes::work{$self->{type}}{$real_num} };
    $self->format_output(\$_, 'l') for values %ret;
    return %ret;
}

# Method to get the labels belonging to the specified work. 

sub browse_location 
{
    my $self = shift;
    my ($auth, $work) = @_;
    my ($lev, @levels);

    my $real_num = $self->parse_idt ($auth);
    $work = sprintf '%03d', $work;

    foreach $lev (sort numerically keys 
                  %{ $Diogenes::level_label{$self->{type}}{$real_num}{$work} }) 
    {
        push @levels, $Diogenes::level_label{$self->{type}}{$real_num}{$work}{$lev};
    }
    my @ret = reverse @levels;
    $self->format_output(\$_, 'l') for @ret;
    return @ret;
}

# Method to read the selected work and to seek to the specified point 
# within it (eg. Book x, Chapter y, line z). 

sub seek_passage 
{
    my $self = shift;
    my ($auth, $work, @array_target) = @_;
    my ($start_block, $end_block, $code, $lev, $top_level, $look_ahead);
    my ($top_num, $target_num, $level_num, $i);
    
    # We turn the passed array into a hash, to match the data gleaned
    # from the .idt file.
    my $index = $#array_target;
    my %target = map {$index-- => $_} @array_target;
    die "Ooops! $index" if $index != -1; 
    $self->{target_levels} = scalar @array_target;
        
    my $orig_auth_num = $auth;
    my $real_num = $self->parse_idt ($auth);
    $work = sprintf '%03d', $work;
        
    # Hack for ddp etc. disk -- .idt files only list `document', which
    # is really the label for level 5, not level 0.
    if ($self->{documentary})
    {
        $target{5} = delete $target{0};
        $target{5} =~ s#([\[\]])#\`$1\`#g; #These are BETA null chars (see above).
    }

    $self->{current_lang} = 'g' unless $self->{type} =~ m/phi|civ/;
    
    my $filename = "$self->{cdrom_dir}$self->{file_prefix}$auth$self->{txt_suffix}";
    $auth = $real_num if defined $real_num;

    # open the file and seek to the beginning of the first block containing
    # our work
    open INP, $filename or $self->barf("Couldn't open $filename");
    binmode INP;
    
    $start_block = $Diogenes::work_start_block{$self->{type}}{$auth}{$work};
    my $next = $work;
    $next++;
    $end_block = $Diogenes::work_start_block{$self->{type}}{$auth}{$next};
    
    print STDERR "Start: $start_block" if $self->{debug}; 
    print STDERR ", End: $end_block\n" if $self->{debug} and $end_block; 

    my $offset = $start_block << 13;
    seek INP, $offset, 0;

    # read the several 8k blocks containing our work
    # Should one have the option to read in only a subsection?
    my $buf;
    $self->{buf} = \$buf;
    if (defined $end_block) 
    {
        read INP, $buf, (($end_block - $start_block + 1) << 13) or
            $self->barf ("Couln't read from $filename!");
    }
    else 
    {
        local $/;
        undef $/;
        $buf = <INP>;
        $self->barf ("Couln't read the rest of $filename!") unless
            defined $buf;
        $end_block = (length $buf) >> 13;
    }
    close INP or $self->barf("Couldn't close $filename");
    
    $self->{work_num} = 0;
    $self->{auth_num} = 0;
    $self->{browse_auth} = $orig_auth_num;
    $self->{browse_work} = $work;
    $self->{current_work} = $work;
        
    # First, we look in the table of contents for starting point
    $top_level = (keys %{ $Diogenes::level_label{$self->{type}}{$auth}{$work} }) - 1;
    my ($block, $old_block);

    if ($self->{type}.$auth =~ /tlg5034|phi1348|phi0588/m )
    {
        print STDERR "Skipping ToC for this wierd author.\n" if $self->{debug};
    }
    else
    {
        # We have to iterate through these levels, since for alphabetic entries, they
        # may not be in any order.
      SECTION:
        for (@{ $Diogenes::top_levels{$self->{type}}{$auth}{$work} })
        {
            $block = @{ $_ }[1];
            my $comp = compare(@{ $_ }[0], $target{$top_level});
            if ($comp >= 0)
            {
                # We've gone too far, so use previous chunk
                print STDERR 
                    ">>>@{ $_ }[0] => $target{$top_level} (using block $old_block)\n" if 
                    $self->{debug};
                $block = $old_block;
                last SECTION;
            }
            $old_block = $block;
        }
        # No match, so we try another trick
        print STDERR "No match in table of contents.\n" if 
            $self->{debug} and not defined $block;
    
        # We now look in the table of last citations per block
        my $cite_block = $block || 0;
      CITE_BLOCK:
        while ($cite_block <= $end_block)
        {
            my $level = $Diogenes::last_citation{$self->{type}}{$auth}{$work}{$cite_block};
            
            unless (defined $level)
            {
                # In case we are in an earlier work
                $cite_block++;
                next CITE_BLOCK;
            }
          LEVEL:
            foreach $lev (reverse sort numerically keys 
                          %{ $Diogenes::level_label{$self->{type}}{$auth}{$work} }) 
            {   
                # See below
                next LEVEL if 
                    $Diogenes::level_label{$self->{type}}{$auth}{$work}{$lev} =~ m#^\*#;
                next LEVEL unless $target{$lev};
                my $result = compare($level->{$lev}, $target{$lev});
                print STDERR 
                    "¨¨¨$level->{$lev} <=> $target{$lev}: res = $result ($lev, $cite_block)\n"
                    if $self->{debug};
                if ($result == 0)
                {
                    next LEVEL;
                }
                elsif ($result == -1)
                {
                    $cite_block++;
                    next CITE_BLOCK;
                }
                else
                {
                    $block = $cite_block;
                    last CITE_BLOCK;
                }
            }
            $block = $cite_block;
            last CITE_BLOCK;
        }
    
        my $next_work = sprintf '%03d', $work + 1;
        $cite_block--; # went one too far
        print STDERR "nw: $next_work, cb: $cite_block\n" if $self->{debug};
        # Next block contains the end of our work but ends in the next work.
        $block = $cite_block if exists 
            $Diogenes::last_citation{$self->{type}}{$auth}{$next_work} and exists
            $Diogenes::last_citation{$self->{type}}{$auth}{$next_work}{$cite_block};
    
        print STDERR "Searching entire work!\n" if $self->{debug} and not defined $block;
    }
    $block ||= 0;
    my $starting_point = ($block - $start_block) << 13 if $block;
    $i = $starting_point || 0;
    $i--;
    # seek through first block to the beginning of the work we want
    while ( 0 + $self->{work_num} < 0 + $work) 
    {
        $code = ord (substr ($buf, ++$i, 1));
        next unless ($code >> 7);
        $self->parse_non_ascii (\$buf, \$i);
    }
    if (0 + $self->{work_num} > 0 + $work)
    {
        warn "Error in searching for start of work: trying again from the beginning\n"
            if $self->{debug};
        $i = 0;
        while ( 0 + $self->{work_num} != 0 + $work) 
        {
            $code = ord (substr ($buf, ++$i, 1));
            next unless ($code >> 7);
            $self->parse_non_ascii (\$buf, \$i);
            print "::" . $self->{work_num} . "\n" if $self->{debug};
        }
    }
    if (0 + $self->{work_num} != 0 + $work)
    {
        die "Error: cannot find the start of the work\n";
    }
    print STDERR "Search begins: $i \n" if $self->{debug};
    
    # read first bookmark
    $code = ord (substr ($buf, ++$i, 1));
    $self->parse_non_ascii (\$buf, \$i) if ($code >> 7);
    
    # Loop in reverse order through the levels, matching eg. first the book, then
    # the chapter, then the line. 
    
  LEV: foreach $lev (reverse sort numerically 
                     keys %{ $Diogenes::level_label{$self->{type}}{$auth}{$work} }) 
  {
      print STDERR "==> $self->{level}{$lev} :: $target{$lev} \n" if $self->{debug};
      # labels that begin with a `*' are not hierarchical wrt the others
      next LEV if $Diogenes::level_label{$self->{type}}{$auth}{$work}{$lev} =~ m#^\*#;
      
      # loop until the count at this level reaches the desired number
      next LEV unless $target{$lev};
      next LEV if (compare($self->{level}{$lev}, $target{$lev}) >= 0);
      
      # Scan the text
    SCAN:   while ($i <= length $buf) 
    { 
        $code = ord (substr ($buf, ++$i, 1));
        next SCAN unless ($code >> 7);
        $self->parse_non_ascii (\$buf, \$i);
        redo SCAN unless defined $self->{level}{$lev};
        
        # String equivalence
        print STDERR "=> $self->{level}{$lev} :: $target{$lev} \n" if $self->{debug};
        last SCAN if (compare($self->{level}{$lev}, $target{$lev}) >= 0);
    } 
      print "Target found: $target{$lev}, level: $self->{level}{$lev}\n" 
          if $self->{debug};
  }
    # Seek to end of current non-ascii block
    while (ord (substr ($buf, $i, 1)) >> 7) { $i++ };
    
    print STDERR "Offset: ", ($i + $offset), "\n" if $self->{debug};
    
    # store a reference to the string holding the text and the start point of the 
    # portion selected.
    $self->{browse_buf_ref} = \$buf;
    $self->{browse_begin} = $i;
    $self->{browse_end} = -1;
    
    return ($offset + $i, -1);  # $abs_begin and $abs_end 
}

sub compare
{
    # As defined by the PHI spec
    # Returns 0 for =, -1 for < and 1 for >
    my ($current, $target) = @_;
    $current ||= 0;

    # Match if we have no target or is zero
    return 1 unless $target;
    $target  ||= 0;

    my ($current_bin, $current_ascii) = $current =~ m/^(\d+)?(.*)$/;
    my ($target_bin,  $target_ascii ) = $target  =~ m/^(\d+)?(.*)$/;
    
    #print "|$current_bin|$current_ascii|$target_bin|$target_ascii|\n";
    
    # Match if leading binary part greater than or equal to target
    return -1 if defined $current_bin and defined $target_bin and 
        $current_bin < $target_bin;
    return  1 if defined $current_bin and defined $target_bin and 
        $current_bin > $target_bin;
    return -1 if not defined $current_bin and defined $target_bin;
    return  1 if defined $current_bin and not defined $target_bin;
    
    # If both are not defined or both are defined and equal, we
    # examine the ascii part
    $current_ascii = lc $current_ascii;
    $target_ascii  = lc $target_ascii;
    return 0 if $current_ascii eq $target_ascii;
    if ((index $target_ascii, ':') == 0)
    {
        # The INS database sometimes has document 1:300[2], etc. where
        # the second half is really ordered numerically
        my ($current_extra_num) = $current_ascii =~ m/^:(\d+)/;
        my ($target_extra_num)  = $target_ascii  =~ m/^:(\d+)/;
        return -1 if defined $current_extra_num and defined $target_extra_num and 
            $current_extra_num < $target_extra_num;
        return  1 if defined $current_extra_num and defined $target_extra_num and 
            $current_extra_num > $target_extra_num;
    }
    # If both are single letters, match alphabetically (important for Plato)
    if ($current_ascii =~ m/^[a-zA-Z]$/ and $target_ascii =~ m/^[a-zA-Z]$/)
    {
        return ord lc $current_ascii <=> ord lc $target_ascii;
    }
    
    # Match if one is a substring of the other, and don't match
    # otherwise, if we are dealing with strings (my addition) --
    # comment it out, since it breaks the Suda (searching for "iota",
    # we hit "t" and then "alpha iota".  return 1 if (index
    # $current_ascii, $target_ascii) >= 0; return 1 if (index
    # $target_ascii, $current_ascii) >= 0;
    return -1 unless defined $current_bin or defined $target_bin;
    
    # Is this really necessary?
    my @current = ($current_ascii =~ m/(\d+|\D)/g);
    my @target  = ($target_ascii  =~ m/(\d+|\D)/g);
    
    for my $n (0 .. $#current)
    {
        return  1 unless defined $target[$n];
        return  1 if $current[$n] =~ m/^\d+$/ and $target[$n] =~ m/^\d+$/ 
            and $current[$n] > $target[$n];
        return -1 if $current[$n] =~ m/^\d+$/ and $target[$n] =~ m/^\d+$/
            and $current[$n] < $target[$n];
        return  0 if $current[$n] =~ m/^\d+$/ and $target[$n] =~ m/^\d+$/;
        
        # We can't match on alphabetic sorting, because most texts don't work that way
        return -1 if $current[$n] =~ m/^\D$/ and $target[$n] =~ m/^\D$/;
        # The PHI spec is unclear and seems contradictory to me on what to do when
        # comparing strings character by character and you have a number on the one
        # hand and a string on the other.
    }
    return 0;
}

#####################################################################
# Private method that prints the location for the following two     #
# methods.  This code is lightly adapted from extract_hits (above). #
#####################################################################

sub print_location 
{
    my $self = shift;
    # args: offset in buffer, reference to buffer
    my ($offset, $ref) = @_;
    my $i;
    my $cgi = (ref $self eq 'Diogenes_browser_stateless') ? 1 : 0;
    my ($location, $code);
    
    $self->set_perseus_links; 
    
    my $block_start = $cgi ? 0 :(($offset >> 13) << 13);
    
    $self->{work_num} = 0;
    $self->{auth_num} = 0;
    
    # Handle out of bounds conditions
    $offset = 0 if $offset < 0;
    $offset = length $$ref if $offset > length $$ref;
    
    for ($i = $block_start; $i <= $offset; $i++ ) 
    {
        $code = ord (substr ($$ref, $i, 1));
        next unless ($code >> 7); # high bit set
        $self->parse_non_ascii ($ref, \$i);             
    }
    # In case we try to read beyond the work currently in memory 
    return 0 
        if (not $cgi and $self->{work_num} != $self->{current_work});
    
    my $this_work = 
        "$Diogenes::author{$self->{type}}{$self->{auth_num}}, " .
        "$Diogenes::work{$self->{type}}{$self->{auth_num}}{$self->{work_num}} ";
    $location = '&';
    $location .= ($self->{print_bib_info} and not 
                  $self->{bib_info_printed}{$self->{auth_num}}{$self->{work_num}})
        ? $self->get_biblio_info($self->{type}, $self->{auth_num}, $self->{work_num})
        : '';
    $self->{bib_info_printed}{$self->{auth_num}}{$self->{work_num}} = 'yes'
        if $self->{print_bib_info}; 
    $location .="\&\n";
                
    foreach (reverse sort keys %{ $self->{level} }) 
    {
        if ($self->{level}{$_} and 
            $Diogenes::level_label{$self->{type}}{$self->{auth_num}}{$self->{work_num}}{$_}) 
        {   # normal case
            $location .=
"$Diogenes::level_label{$self->{type}}{$self->{auth_num}}{$self->{work_num}}{$_}".
                " $self->{level}{$_}, "
        }
        elsif ($self->{level}{$_} ne '1') 
        {   # The Theognis exception 
            # and what unused levels in the ddp and ins default to
            $location .= "$self->{level}{$_}, ";
        }
    }
    $location =~ s/, $//;
    if ($self->{special_note}) 
    {
        $location .= "\nNB. $self->{special_note}";
        undef $self->{special_note};
    }
    
    $location .= "\n";
    $self->print_output(\$location);
    
    return 1;   
}

sub numerically { $a <=> $b; }

#############################################################################
#                                                                           #
# Method to print out the lines following the currently selected point in   #
# the file.      Select the default number of lines via `browse_lines'.     #
#                                                                           #
#############################################################################

sub browse_forward 
{
    my $self = shift;
    my ($abs_begin, $abs_end, $auth, $work);
    my ($ref, $begin, $end, $line, $result, $buf, $offset);
    $self->set_perseus_links; 
    
    if (ref $self eq 'Diogenes_browser')
    {   # Get persistent browser info from object
        $ref = $self->{browse_buf_ref};
        $self->{browse_begin} = $self->{browse_end} unless $self->{browse_end} == -1;
        $begin = $self->{browse_begin};
        $offset = 0;
    }
    elsif (ref $self eq 'Diogenes_browser_stateless')
    {       # Browser info is passed as arguments
        ($abs_begin, $abs_end, $auth, $work) = @_;
        $auth = 1 if  $self->{type} eq 'bib' and $auth =~ m/9999/;
        
        $begin = ($abs_end == -1) ? $abs_begin : $abs_end;
        $self->{current_work} = $work;
        $self->parse_idt ($auth);
        
        # open the file and seek to the beginning of the first block containing
        # our start-point
        open INP, "$self->{cdrom_dir}$self->{file_prefix}$auth$self->{txt_suffix}" or
            $self->barf("Couldn't open $self->{file_prefix}$auth$self->{txt_suffix}");
        binmode INP;
                
        my $start_block = $begin >> 13;
        $offset = $start_block  << 13;
        seek INP, $offset, 0;
        
        # read three 8k blocks for each pass -- should be enough!
        my $amount = 8192 * 3 * $self->{browser_multiple};
        read INP, $buf, $amount or 
            die "Could not read from file $self->{file_prefix}$auth.txt!\n" .
            "End of file?";
        
        close INP or $self->barf("Couldn't close $self->{file_prefix}$auth.txt");
        $ref = \$buf;
        $self->{browse_begin} = $begin;
        $begin = $begin - $offset;
    }
    else
    { 
        die "What is ".ref $self."?\n"
    }
    print STDERR "Beginning: $begin\n" if $self->{debug}; 
    
  PASS:
    for (my $pass = 0; $pass < $self->{browser_multiple}; $pass++)
    {
        
        # find the right length of chunk for this pass
      CHUNK:      for ($end = $begin, $line = 0; 
                       ($line <= $self->{browse_lines}) and ($end < length $$ref) ; 
                       $end++) 
      {
          $line++ if ((ord (substr ($$ref, $end, 1)) >> 7) and not
                      (ord (substr ($$ref, $end + 1, 1)) >> 7)) ; 
          # for papyri, etc. get only one document at a time
          if ($self->{documentary} and ord (substr ($$ref, $end, 1)) >= hex 'd0'
              and ord (substr ($$ref, $end, 1)) <= hex 'df'
              and not ord (substr ($$ref, $end - 1, 1)) >> 7)
          {       # Seek to end of non-ascii block beginning with \xd0 -- \xdf
              while (ord (substr ($$ref, $end, 1)) >> 7)      { $end++ };
              last CHUNK;
          }
          if (substr ($$ref, $end, 2) eq "\xfe\x00") # EoB
          {
              $end++;
              while (substr ($$ref, $end, 1) eq "\x00")  { $end++; };
              
          }
      }
        $result = substr ($$ref, $begin, ($end - $begin));
        my $base = ($self->{current_lang} eq 'g')
            ? '$'
            : '&';
        $result = $base . "\n" . $result  ;
        
        if ($self->print_location ($begin, $ref))
        {
            $self->print_output (\$result);
        }
        else
        {
            print "Sorry.  That's beyond the scope of the requested work.\n" unless 
                $self->{quiet};
            last PASS;
        }
        $begin = $end;
    }
    # Store and pass back the start and end points of the whole session
    $self->{browse_end} = $end + $offset;
    return ($self->{browse_begin}, $end + $offset);  # $abs_begin and $abs_end
}

#############################################################################
#                                                                           #
# Method to print out the lines immediately preceding the previously        #
# specified point in our work.                                              #
#                                                                           #
#############################################################################

sub browse_backward 
{
    my $self = shift;
    my ($abs_begin, $abs_end, $auth, $work);
    my ($ref, $begin, $end, $line, $result, $buf, $offset);
    my @frames;
    
    $self->set_perseus_links; 
    
    if (ref $self eq 'Diogenes_browser')
    {   # Get persistent browser info from object
        $ref = $self->{browse_buf_ref};
        $end = $self->{browse_begin};
        $self->{browse_end} = $end;
        $offset = 0;
    }
    elsif (ref $self eq 'Diogenes_browser_stateless')
    {       # Browser info is passed as arguments
        ($abs_begin, $abs_end, $auth, $work) = @_;
        $auth = 1 if  $self->{type} eq 'bib' and $auth =~ m/9999/;
        
        $end = $abs_begin;
        $self->{current_work} = $work;
        $self->parse_idt ($auth);
        $self->{browse_auth} = $auth;
        $self->{browse_work} = $work;
        
        # open the file and seek to the beginning of the first block containing
        # our start-point
        open INP, "$self->{cdrom_dir}$self->{file_prefix}$auth$self->{txt_suffix}" or
            $self->barf("Couldn't open $self->{file_prefix}$auth$self->{txt_suffix}");
        binmode INP;
        
        my $end_block = $end >> 13;
        # read four 8k blocks for each pass -- should be enough!
        my $blocks = 4;
        my $start_block = $end_block - ($self->{browser_multiple} * ($blocks - 1));
        $start_block = 0 if $start_block < 0;
        $offset = $start_block  << 13;
        seek INP, $offset, 0;

        my $amount = 8192 * $blocks * $self->{browser_multiple};
        read INP, $buf, $amount or 
            die "Could not read from file $self->{file_prefix}$auth.txt!\n" ;
        
        close INP or die "Couldn't close $self->{file_prefix}$auth.txt";
        $ref = \$buf;
        $self->{browse_end} = $end;
        $end = $end - $offset;
    }
    else
    { 
        die "What is ".ref $self."?\n"
    }
    
    for (my $pass = 0; $pass < $self->{browser_multiple}; $pass++)
    {
        $begin = $end; 
        # Seek to beginning of any preceding  non-ascii block
        while (ord (substr ($$ref, --$begin, 1)) >> 7)  { };
        
        # find the right length of chunk for this pass
      CHUNK:  for ($line = 0; 
                   ($line <= $self->{browse_lines} + 1) and ($begin > 0) ; 
                   $begin--) 
      {
          next if (ord (substr ($$ref, $begin, 1)) == 0);
          $line++ if ((ord (substr ($$ref, $begin, 1)) >> 7) and not
                      (ord (substr ($$ref, $begin - 1, 1)) >> 7)) ; 
          # for papyri, etc. get only one document at a time
          if ($self->{documentary} and ord (substr ($$ref, $begin, 1)) >= hex 'd0'
              and ord (substr ($$ref, $begin, 1)) <= hex 'df'
              and not ord (substr ($$ref, $begin - 1, 1)) >> 7)
          {       # Seek to end of non-ascii block beginning with \xd0 -- \xdf
              while (ord (substr ($$ref, $begin, 1)) >> 7)    { $begin++ };
              $begin--;
              last CHUNK;
          }
      }
        push @frames, [$begin, $end];
        $end = $begin;
    }
    print STDERR "Beginning: $begin\n" if $self->{debug}; 
    
  FRAME:
    for my $frame (reverse @frames)
    {
        my ($start_point, $end_point) = @{ $frame };
        $result = substr ($$ref, $start_point, ($end_point - $start_point));
        my $base = ($self->{current_lang} eq 'g')
            ? '$'
            : '&';
        $result = $base . $result . "\n";
        
        if ($self->print_location ($start_point + 1, $ref))
        {
            $self->print_output (\$result);
        }
        else
        {
            my @beginning = (0) x $self->{target_levels};
            $self->seek_passage ($self->{browse_auth}, $self->{browse_work},
                                 @beginning);
            $self->browse_forward;
            last FRAME;
        }
    }
    # Store and pass back the start and end points of the whole session
    $self->{browse_begin} = $offset + $begin + 1;
    return ($self->{browse_begin}, $self->{browse_end});  # $abs_begin and $abs_end
}

#############################################
#-------------------------------------------#
#------------CGI File Browser---------------#
#-------------------------------------------#
#############################################

# As above, except with CGI scripts we have to re-read the text, since
# we don't want to hold it in memory between invocations.

package Diogenes_browser_stateless;
@Diogenes_browser_stateless::ISA = qw( Diogenes_browser );

# Everything is delegated to the parent -- browse_forward and
# browse_backward work somewhat differently and expect arguments

1;

# End of file Diogenes.pm
# ex: set shiftwidth=4 nowrap ts=4: #
