#!/usr/bin/perl -w

##########################################################################
#                                                                        #
# Diogenes is a set of programs including this CGI script which provides #
# a graphical interface to the CD-Rom databases published by the         #
# Thesaurus Linguae Graecae and the Packard Humanities Institute.        #
#                                                                        #
# Copyright P.J. Heslin 1999 - 2005.                                     #
# Diogenes comes with ABSOLUTELY NO WARRANTY;                            #
# for details see the file named COPYING.                                #
#                                                                        #
##########################################################################

package Diogenes::CGI;

use Data::Dumper;

use Diogenes::Base qw(%encoding %context @contexts %choices %work %author %database @databases @filters);
# use Diogenes::CGI_utils qw($f %st $get_state $set_state);
use Diogenes::Search;
use Diogenes::Indexed;
use Diogenes::Browser;

use strict;
use File::Spec::Functions qw(:ALL);
use Encode;

$Diogenes::Base::cgi_flag = 1;

my $f = $Diogenes_Daemon::params ? new CGI($Diogenes_Daemon::params) : new CGI;
my $user = $f->cookie('userID');

# binmode STDOUT, ':utf8';

# Force read of config files 
my %args_init = (-type => 'none');
$args_init{user} = $user if $user;
my $init = new Diogenes::Base(%args_init);
my $filter_file = $init->{filter_file};
my $font = $init->{cgi_font};

# my @choices = reverse sort keys %choices;
my @choices = (
    'TLG Texts',
    'PHI Latin Corpus',
    'Duke Documentary Papyri',
    'Classical Inscriptions',
    'Christian Inscriptions',
    'Miscellaneous PHI Texts',
    'PHI Coptic Texts',
    'TLG Bibliography',
    );

# Probable input language for morphological search
my %prob_lang = ( 'phi' => 'lat',
                  'tlg' => 'grk',
                  'ddp' => 'grk',
                  'ins' => 'grk',
                  'chr' => 'grk',
                  'misc' => 'lat' );
my $default_choice;
my $choice_from_config = quotemeta $init->{cgi_default_corpus};
for (@choices)
{
    if ($_ =~ m/$choice_from_config/i)
    {
        $default_choice = $_;
        last;
    }
}
warn "I don't understand default search type $init->{cgi_default_corpus}\n"
    unless $default_choice;

my $default_encoding = $init->{cgi_default_encoding} || 'UTF-8';

my $default_criteria = $init->{default_criteria};

# This is the directory whence the decorative images that come with
# the script are served.
my $picture_dir = 'images/';

my $check_mod_perl = $init->{check_mod_perl};

my $version = $Diogenes::Base::Version;
my (%handler, %output, $filter_flag);

use CGI qw(:standard);
#use CGI;
# use CGI::Carp 'fatalsToBrowser';
$ENV{PATH} = "/bin/:/usr/bin/";
$| = 1;


# We need to pre-set the encoding for the earlier pages, so that the right
# header is sent out the first time Greek is displayed
$f->param('greek_output_format', $default_encoding) unless
    $f->param('greek_output_format');

# This works for WinGreek, etc, and any encoding/font that's designed
# more for cutting and pasting than for proper viewing in a browser.
my $charset = 'iso-8859-1';

if ($f->param('greek_output_format') and
    $f->param('greek_output_format') =~ m/UTF-?8|Unicode/i)
{
    $charset = 'UTF-8';
    #$charset = 'iso-10646-1';
}
elsif ($f->param('greek_output_format') and
       $f->param('greek_output_format') =~ m/8859.?7/i)
{
    $charset = 'ISO-8859-7';
}

# Preserving state: all previous parameters are embedded as hidden
# fields in each subsequent page.
my %st;
# Remember that this sets up a single namespace for all cgi
# parameters on all pages of the script, so be careful not to
# duplicate parameter names from page to page.

my $set_state = sub
{
    for (keys %st)
    {
        print $f->hidden( -name => $_.'XXstate',
                          -default => $st{$_},
                          -override => 1 );
    }
};

# Put cgi parameters into %st, putting multi-valued params into array
# refs.  Some lists should always be lists, however, even single-valued.

# If a named param is hidden (previous state) it should not override
# any unhidden parameter of the same name.  If we have come back to
# the same page, we want the new value, not the old one or a list of
# both.  So old state params have XXstate appended to them.  This
# allows us to avoid restoring the state of params which have new,
# real values for this submission.

my $get_state = sub
{
    my @params = $f->param();
    my %real_params;
    /XXstate$/ || $real_params{$_}++ for @params;

    for my $p ( @params )
    {
        my $r = $p;
        $r =~ s/XXstate$//;
        next if $p =~ m/XXstate$/ and exists $real_params{$r};
        my @tmp = $f->param($p);
        if ($init->{input_encoding} eq 'Unicode') {
            @tmp = map {Encode::decode(utf8=>$_) } @tmp;
        }
        if ( scalar @tmp == 1 and not $r =~ /_list/)
        {
            $st{$r} = $tmp[0];
        }
        else
        {
            $st{$r} = [ @tmp ];
        }
    }
};

$get_state->();

my $read_filters = sub {
    if (-e $filter_file)
    {
        open my $filter_fh, "<$filter_file"
            or die "Can't read from filter file ($filter_file): $!";
        
        local $/ = undef;
        my $code = <$filter_fh>;
        eval $code;
        warn "Error reading in saved corpora: $@" if $@;
        
        close $filter_fh or die "Can't close filter file ($filter_file): $!";

#         print STDERR Data::Dumper->Dump([\@filters], ['*filters']);

    }
};

$read_filters->() unless @filters;


my $previous_page = $st{current_page};

my $essential_footer = sub
{
    $set_state->();
    print '</div>'; # font div
    print $f->end_form,
    $f->end_html;
};

my $my_footer = sub
{                                                       
    print $f->hr,
    $f->center(

        $f->p(qq(<font size="-1">All data is &copy; the <em>Thesaurus
        Linguae Graecae</em>, the Packard Humanities Institute, The Perseus Project and
        others. The information in these databases is subject to
        restrictions on access and use; consult your licenses.  <a
        href="http://www.durham.ac.uk/p.j.heslin/Software/Diogenes/">Diogenes</a>
        (version $version) is <a
        href="http://www.durham.ac.uk/p.j.heslin/Software/Diogenes/license.php">&copy;</a>
        1999-2007 P.J. Heslin.  </font>)),

        $f->p('<a href="Diogenes.cgi" title="New Diogenes Search">New Search</a>'));
    $essential_footer->();
};


my $print_error_page = sub 
{
    my $msg = shift;
    $msg ||= 'Sorry. You seem to have made a request that I do not understand.';
    print $f->header(-type=>"text/html; charset=$charset");
    print
        $f->start_html( -title =>'Diogenes Error Page',
                        -style => {-type=>'text/plain', -src=>'diogenes.css'}),
        $f->center(
            $f->p($msg)),
        $f->end_html;
     exit;
};

my $print_title = sub 
{
    print $f->header(-type=>"text/html; charset=$charset");
    my $title = shift;
    my $newpage = shift;
    print
        $f->start_html(-title=>$title,
                       -encoding=>$charset,
                       -script=>{-type=>'text/javascript',
                                 -src=>'diogenes-cgi.js'},
                       -style=>{ -type=>'text/css',
                                 -src=>'diogenes.css'},
                       -meta=>{'content' => 'text/html;charset=utf-8'}
        ),
    "\n",
    $f->start_form(-name=>'form', -id=>'form', -method=> 'get');
    # We put this here (other hidden fields are at the end), so that
    # Javascript can use it for jumpTo even before the page has
    # completely loaded.
    print $f->hidden( -name => 'JumpTo',
                      -default => "",
                      -override => 1 );
    # So that Perseus.cgi can use this value when making a pop-up
    print $f->hidden( -name => 'FontName',
                      -default => "$font" || '',
                      -override => 1 );
 
    # for Perseus data
    if ($newpage) {
        # For when what we show first is Perseus data (we don't want a
        # perseus sidebar within a perseus page
        print qq{<div id="sidebar" class="sidebar-newpage" style="font-family: '$font'"></div>};
    } else {
        print qq{<div id="sidebar" class="sidebar-$init->{perseus_show}" style="font-family: '$font'"></div>};
    }
    if ($font) {
        print qq{<div id="main_window" class="main-full" style="font-family: '$font'">};
    } else {
        print '<div id="main_window" class="main-full">';
    }
    
};

my $print_header = sub 
{
    # HTML output
    print qq(
        <center>
             <a id="logo" href="Diogenes.cgi" title="New Diogenes Search">
               <img src="${picture_dir}Diogenes_Logo_Small.gif" alt="Logo"
                height="38" width="109" align="center" hspace="24" border="0"
                /></a>
       </center>);
};

my $strip_html = sub
{
    my $ref = shift;
    $$ref =~ s#<[^>]*>##g;
    $$ref =~ s#&amp;#&#g;
    $$ref =~ s#&lt;#<#g;
    $$ref =~ s#&gt;#>#g;
    $$ref =~ s#&quot;#"#g;
    $$ref =~ s#&nbsp;# #g;
    $$ref =~ s/&#14[78];/"/g;
    $$ref =~ s/&#x?[0-9a-fA-F]+;/ /g;
};

my $database_error = sub
{
    my $self = shift;
    my $disk_type = $st{short_type};
    if ($disk_type eq 'cop' or $disk_type eq 'ins' or $disk_type eq 'chr') {
        $disk_type = 'ddp';
    }
    elsif ($disk_type eq 'misc') {
        $disk_type = 'phi';
    }
    elsif ($disk_type eq 'bib') {
        $disk_type = 'tlg';
    }
    $print_title->('Database Error');
    print qq(<center>
              <div style="display: block; width: 50%; text-align: center;">
                  <h2 id="database-error" type="$disk_type"
                      long-type="$st{type}">Error: Database not found</h2>
         </div>
         </center>
                );

    $st{current_page} = 'splash';
    $essential_footer->();
    exit;
};

### Splash page

my %input_blurb = (

    'Unicode' => qq{<strong>NB. Unicode input is new.</strong> You
    must type Greek using your computer's facility to type Greek
    letters in Unicode, and you should either type all accents or none
    at all.  <a href="Unicode_input.html">Further info.</a>},

    'Perseus-style' => qq{Here is <a href="Perseus_input.html">further
    info</a> on this style of Latin transliteration.},

    'BETA code' => qq{Here is <a href="Beta_input.html">further
    info</a> on this style of Latin transliteration.}
    );

$output{splash} = sub 
{
    # If you change this list, you may have to change onActionChange() in diogenes-cgi.js
    my @actions = ('search',
                   'word_list',
                   'multiple',
                   'lemma',
                   'lookup',
                   'parse',
                   'browse',
                   'filters');
    
    my %action_labels = ('search' => 'Simple search for a word or phrase',
                         'word_list' => 'Search the TLG using its word-list',
                         'multiple' => 'Search for conjunctions of multiple words or phrases',
                         'lemma' => 'Morphological search',
                         'lookup' => 'Look up a word in the dictionary',
                         'parse' => 'Parse the inflection of a Greek or Latin word',
                         'browse' => 'Browse to a specific passage in a given text',
                         'filters' => 'Manage user-defined corpora');

    my @corpora = @choices;
    my @filter_names;
    push @filter_names, $_->{name} for @filters;

    $print_title->('Diogenes');
    $st{current_page} = 'splash';
    
    print $f->center(
        $f->img({-src=>$picture_dir.'Diogenes_Logo.gif',
                 -alt=>'Diogenes', 
                 -height=>'137', 
                 -width=>'383'})),
        $f->start_form(-id=>'form', -method=> 'get');


    print $f->p('Welcome to Diogenes, a tool for searching and
        browsing through databases of ancient texts. Choose your type
        of query, then the corpus, then type in the query itself: this
        can be either some Greek or Latin to <strong>search</strong>
        for, or the name of an author whose work you wish to
        <strong>browse</strong> through.'),

        $f->p("The Greek input method you have currently selected is:
        $init->{input_encoding}.  ".$input_blurb{$init->{input_encoding}} .

        "  This and other settings can be displayed and changed via the <a href=\"Settings.cgi\"> current settings
        page</a>.");


    print $f->center(
        $f->table({cellspacing=>'10px'},
            $f->Tr(
                $f->th({align=>'right'}, 'Action: '),
                $f->td($f->popup_menu(
                           -name=>'action',
                           -id=>'action_menu',
                           -onChange=>'onActionChange();',
                           -Values=>\@actions,
                           -labels=>\%action_labels,
                           -Default=>'Simple search for a word or phrase'))),
            $f->Tr(
                $f->th({align=>'right'}, 'Corpus: '),
                $f->td($f->popup_menu(
                           -name=>'corpus',
                           -id=>'corpus_menu',
                           -Values=>[
                                $f->optgroup( -name=>'Databases',
                                              -values=>\@corpora),
                                $f->optgroup( -name=>'User-defined corpora',
                                              -values=>\@filter_names),
                           ],
                           -Default=>$default_choice))),
            $f->Tr(
                $f->th({align=>'right'}, 'Query: '),
                $f->td($f->textfield(
                           -id=>'query_text',
                           -name=>'query',
                           -size=>40),
                       ' ',
                       $f->submit( -name =>'go',
                                   -value=>'Go')))));
    

    print $f->p('&nbsp;');

    $my_footer->();
        
};

my $current_filter;
my $get_filter = sub
{
    my $name = shift;
    for (@filters) {
        return $_ if $_->{name} eq $name;
    }
#     die ("Filter for $name not found!");
    return undef;
};

### Splash handler

$handler{splash} = sub
{

    my $corpus = $st{corpus};
    my $action = $st{action};
    if ($choices{$corpus}) 
    {
        # Convert to abbreviated form
        $st{short_type} = $choices{$corpus};
        $st{type} = $corpus;
    }
    else
    {
        $current_filter = $get_filter->($corpus);
        $st{short_type} = $current_filter->{type};
        $st{type} = $corpus;
    }

    if ((not $st{query}) and $action eq 'search')
    {
        $print_title->('Error');
        print $f->center($f->p($f->strong('Error.')),
                         $f->p('You must specify a search pattern.'));
    }
    elsif ($action eq 'filters') 
    {
        $output{filter_splash}->();
    }
    elsif ($action eq 'lemma') 
    {
        $output{lemma}->();
    }
    elsif ($action eq 'lookup' or $action eq 'parse') 
    {
        $output{lookup}->($action);
    }
    elsif ($action eq 'search') 
    {
        $output{search}->();
    }
    elsif ($action eq 'multiple')
    {
        $output{multiple}->();
    }
    elsif ($action eq 'word_list')
    {
        if ($current_filter and $current_filter->{type} ne 'tlg') {
            $print_title->('Error');
            print
                $f->center(
                    $f->p($f->strong('Error.'),
                          'You have requested to do a TLG word search on a user-defined corpus
 which is not a subset of the TLG.'));
        }
        else {
            $st{short_type} = 'tlg';
            $st{type} = 'TLG Word List';
            $output{indexed_search}->();
        }
    }
    elsif ($action eq 'browse') 
    {
        $output{browser}->();
    }
    else
    {
        $print_title->('Error');
        print $f->center($f->p($f->strong('Flow Error.')));
    }

};

$output{multiple} = sub 
{
    $print_title->('Diogenes Multiple Search Page');
    $print_header->();
    $st{current_page} = 'multiple';
    # Since this is a multiple-step search, we have to save it.
    $st{saved_filter} = $st{corpus} if $current_filter;
    
    my $new_pattern = $st{query};

    print '<div style="margin-left: auto; margin-right: auto; width: 50%">';
    print
        $f->h1('Multiple Patterns'),
        $f->p( 'Use this page to search for multiple words or phrases
         within a particular scope');

    my @patterns = ();
    @patterns = @{ $st{query_list} } if $st{query_list};
    push @patterns, $new_pattern if $new_pattern;
    $st{query_list} = \@patterns;
    
    if (@patterns)
    {
        print
            $f->h2('Patterns Entered:'),
            $f->p('Here is a list of the patterns you have entered thus far:');
        print '<p><ol>';
        print "<li>$_</li>\n" foreach @patterns;
        print '</ol></p>';
    }
    
    print
        $f->h2('Add a Pattern'),
        $f->p('You may add a' . (@patterns ? 'nother' : '') . ' pattern:'),
            $f->p(
                $f->textfield(-name=>'query', -size=>40, -default=>'',
                              -override=>1)),
            $f->p(
                $f->submit(-name=>'Add_Pattern',
                           -value=>'Add this pattern to the list'));

    my @matches = ('any', 2 .. $#patterns, 'all');
    

    print
        $f->hr(),
        $f->h1('Search Options'),
        $f->h2('Scope'),
        $f->p( 'Define the scope within which these patterns are to
    be found together.  The number of lines is an exact measure,
    whereas the others depend on punctuation, which is guesswork.'),
        $f->popup_menu( -name => 'context',
                        -Values => \@contexts,
                        -Default => 'sentence');

    print
        $f->h2('Quantity'),
        $f->p('Define the minimum number of these patterns that must be ',
              'present within a given scope in order to qualify as a successful ',
              'match.'),
        $f->popup_menu( -name => 'min_matches',
                        -Values => \@matches,
                        -Default => 'all');

    print
        $f->h2('Reject pattern'),
        $f->p('Optionally, if there is a word or phrase whose presence in a given ',
              'context should cause a match to be rejected, specify it here.'),
        $f->textfield( -name => 'reject_pattern',
                       -size => 50,
                       -default => '');

    print
        $f->p('&nbsp;'),
        $f->center(
            $f->p(
                $f->submit( -name =>'do_search',
                            -value=>'Do Search')));

    print '</div>';
    $my_footer->();
};

$handler{multiple} = sub
{
#     push @{ $st{query_list} }, $st{query};

    if ($st{do_search})
    {
        $output{search}->();
    }
    else
    {
        $output{multiple}->();
    }
};

my $get_args = sub
{
    my %args = (
        type => $st{short_type},
        output_format => 'html',
        highlight => 1,
        );
    $args{user} = $user if $user;

    # These don't matter for indexed searches
    if (exists $st{query_list})
    {
        $args{pattern_list} = $st{query_list};
    }
    else
    {
        $args{pattern} = $st{query};
    }
    
    for my $arg (qw(context min_matches reject_pattern))
    {
        $args{$arg} = $st{$arg} if $st{$arg};
    }
    $args{context} = '2 lines' if $st{type} =~ m/inscriptions|papyri/i
                               and not exists $st{context};

    $args{encoding} = $st{greek_output_format} || $default_encoding;
    
    return %args;
};

my $use_and_show_filter = sub
{
    my $q = shift;
    my $filter;
    $filter = $current_filter ? $current_filter :
        ($st{saved_filter} ? $get_filter->($st{saved_filter}) : undef);
    if ($filter)
    {
        my $work_nums = $filter->{authors};
        my @texts = $q->select_authors( -author_nums => $work_nums);
        
        print
            $f->p('Searching in the following: '),
            (join '<br />', @texts),
            $f->hr;
    }
};

$output{lookup} = sub {
    my $action = shift;
    $print_title->('Diogenes Perseus Lookup Page', 1);
    $print_header->();
    $st{current_page} = 'lookup';

    my $lang = $prob_lang{$st{short_type}};
    my $inp_enc = $init->{input_encoding};
    my $query = $st{query};
    $query =~ s/\s//g;
    if ($inp_enc eq 'Unicode') {
        $lang = ($query =~ m/^[\x01-\x7f]+$/) ? 'lat' : 'grk';
    }
    $lang = 'eng' if $query =~ s/^@//;
#     my $perseus_params = qq{do=$action&lang=$lang&q=$query&popup=1&noheader=1&inp_enc=$inp_enc};
    my $perseus_params = qq{do=$action&lang=$lang&q=$query&noheader=1&inp_enc=$inp_enc};
    print STDERR ">>$perseus_params\n"  if $init->{debug};
    $Diogenes_Daemon::params = $perseus_params;
    do "Perseus.cgi" or die $!;
    
    $my_footer->();
    
};


$output{lemma} = sub {
    $print_title->('Diogenes Lemma Search Page');
    $print_header->();
    $st{current_page} = 'lemma';
    # Since this is a multiple-step search, we have to save it.
    $st{saved_filter} = $st{corpus} if $current_filter;
    my %args = $get_args->();
    my $q = new Diogenes::Base(%args);
    $st{lang} = $q->{input_lang} =~ m/g/i ? 'grk' : 'lat';
    my $inp_enc = $init->{input_encoding};
    my $perseus_params = qq{do=lemma&lang=$st{lang}&q=$st{query}&noheader=1&inp_enc=}.$inp_enc;
    print STDERR ">>$perseus_params\n" if $init->{debug};
    $Diogenes_Daemon::params = $perseus_params;
    do "Perseus.cgi" or die $!;
    
    print
        $f->p(
            $f->button( -Value  =>"Select All",
                        -onClick=>"setAll()"),
            '&nbsp;&nbsp;&nbsp;&nbsp;',
            $f->reset( -value  =>'Deselect All')),
        $f->p('Select the lemmata above that interest you.'),
    
        $f->submit( -name => 'proceed',
                    -Value  =>'Show Inflected Forms');

    $my_footer->();
    
};

$handler{lemma} = sub {
    $output{lemmata}->();
};

$output{lemmata} = sub {
    $print_title->('Diogenes Lemma Choice Page');
    $print_header->();
    my $n = 0;
    $st{current_page} = 'inflections';
    my $lem_string = join " ", @{ $st{lemma_list} }; 
    $Diogenes_Daemon::params = qq{do=inflects&lang=$st{lang}&q=$lem_string&noheader=1};
    do "Perseus.cgi" or die $!;

    print
        $f->hr,
        $f->p('Show only forms matching this text (e.g. "aor opt" for only aorist optatives):',
              $f->br,
              $f->textfield(-name => 'form_filter',
                            -id => 'form_filter',
                            -default => '',
                            -size => 25),
              '&nbsp;<a onClick="formFilter();">Go</a>');
    
    print qq{<p><a onClick="selectVisible(true);">Select All Visible Forms</a><br>
<a onClick="selectVisible(false);">Unselect All Visible Forms</a></p>};

    
    print
        $f->p(
            $f->submit( -name => 'proceed',
                        -Value  =>'Search for selected forms'),
            qq{(Current corpus: $st{type})});

    $my_footer->();
};

$handler{inflections} = sub {
    $print_title->('Diogenes Morphological Search');
    $print_header->();
    if ($st{short_type} eq "tlg") {
        my %args = $get_args->();
        $args{use_tlgwlinx} = 1;
        my $q = new Diogenes::Indexed(%args);
        $database_error->($q) if not $q->check_db;
        $use_and_show_filter->($q);

        my %seen = ();
        for my $upcase (@{ $st{lemma_list} }) {
            $upcase =~ tr/a-z/A-Z/;
            unless ($seen{$upcase}) {
                my $bare = $upcase;
                $bare =~ s/[^A-Z]//g;
                $q->{input_raw} = 1;
                my ($ref, @wlist) = $q->read_index($bare);
                # Make sure we get back what we put in
                warn "Inflection $upcase is not in the word-list!\n" unless exists $ref->{$upcase};
                $seen{$_}++ for @wlist;
            }
        }
        # Since the morphological variants of a given lemma can look
        # very heterogeneous, it doesn't make sense to search for them
        # via one big regexp as would be the case for
        # $q->do_search($st{lemma_list}).  Instead we pass an array of
        # single-element arrays to treat each word as a separate
        # "word-set".
        my @word_sets;
        push @word_sets, [$_] for @{ $st{lemma_list} };
        $q->do_search(@word_sets);
    }
    else {
        # Simple searches
        delete $st{query};
        for my $form (@{ $st{lemma_list} }) {
            push @{ $st{query_list} }, " $form ";
        }
        my %args = $get_args->();
        my $q = new Diogenes::Search(%args);
        if ($prob_lang{$st{short_type}} eq "grk") {
            $args{input_encoding} = 'BETA code';
        }
        $database_error->($q) if not $q->check_db;
        $use_and_show_filter->($q);
        $q->do_search();
    }
};

$output{indexed_search} = sub 
{
    my %args = $get_args->();
    my $q = new Diogenes::Indexed(%args);
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes TLG word list result');
    $print_header->();
    $st{current_page} = 'word_list';
    my @params = $f->param;
    
    $use_and_show_filter->($q);
    # Since this is a 2-step search, we have to save it.
    $st{saved_filter} = $st{corpus} if $current_filter;

    my $pattern_list = $st{query_list} ? $st{query_list} : [$st{query}];
    print $f->p('Here are the entries in the TLG word list that match your ',
                $st{query_list} ? 'queries: ' : 'query: ');

    for my $pattern (@{ $pattern_list })
    {
        my ($wref, @wlist) = $q->read_index($pattern) if $pattern;

        if (not @wlist)
        {
            print $f->p(
                $f->strong('Error'),
                "Nothing maches $pattern in the TLG word list!");
            return;
        }

        my %labels;
        foreach my $word (@wlist) 
        {
            $labels{$word} = $word;
            $q->encode_greek($default_encoding, \$labels{$word});
            $labels{$word} .= "&nbsp;($wref->{$word}) ";
        }
        $f->autoEscape(undef);
        print $f->checkbox_group( -name => "word_list",
                                  -Values => \@wlist,
                                  -labels => \%labels, 
                                  -columns=>'3' );
        
        $f->autoEscape(1) ;
        print $f->hr;
    }

    print
        $f->p(
            $f->button( -Value  =>"Select All",
                        -onClick=>"setAll()"),
            '&nbsp;&nbsp;&nbsp;&nbsp;',
            $f->reset( -value  =>'Deselect All')),
        $f->p('Select the forms above that interest you.'),
    
        $f->submit( -name => 'search',
                    -Value  =>'Do Search');
    $my_footer->();
};

$handler{word_list} = sub
{
    $filter_flag = $st{saved_filter_flag} if $st{saved_filter_flag};
    $output{search}->()
};


$output{search} = sub 
{
    if ($st{type} =~ m/TLG Word List/ and not $st{word_list}) 
    {
        $output{indexed_search}->();
        return;
    }    

    $st{current_page} = 'doing_search';

    my %args = $get_args->();

    my $q;
    if ($st{type} =~ m/TLG Word List/)
    {
        $q = new Diogenes::Indexed(%args);
    }
    else
    {
        $q = new Diogenes::Search( %args );
    }
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes Search');
    $print_header->();

    $use_and_show_filter->($q);

    if ($st{type} =~ m/TLG Word List/)
    {
        my $patterns = $st{query_list} ? $st{query_list} : [$st{query}];
        $q->read_index($_) for @{ $patterns };
        $q->do_search($st{word_list})
    }
    else
    {
        $q->do_search;
    }
    $my_footer->();
    
};      




$handler{doing_search} = sub
{
    warn("Unreachable code!");
};


$output{browser} = sub 
{
    my %args = $get_args->();
    my $q = new Diogenes::Browser::Stateless(%args);
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes Author Browser');
    $print_header->();
    $st{current_page} = 'browser_authors';

    my %auths = $q->browse_authors($st{query});

    # Because they are going into form elements, and most browsers
    # do not allow HTML there.
     $strip_html->(\$_) for values %auths;

    if (keys %auths == 0) 
    {
        print
            $f->p($f->strong('Sorry, no matching author names')),
            $f->p(
                'To browse texts, enter part of the name of the author ',
                'or corpus you wish to examine.'),
            $f->p('To get a list of all authors, simply leave the text area blank.');
    }
    elsif (keys %auths == 1) 
    {
        my $auth = (keys %auths)[0];
        
        print
            $f->center(
                $f->p(
                    'There is only one author corresponding to your request:'),
                $f->p($auths{$auth}),
                $f->submit( -name => 'submit',
                            -value => 'Show works by this author'));
        $st{author} = [keys %auths]->[0];
    }
    else 
    {
        my $size = keys %auths;
        $size = 20 if $size > 20;
        print
            $f->center(
                $f->p( 'Here is a list of authors corresponding to your request.'),
                $f->p( 'Please select one and click on the button below.'),
                $f->p(
                    $f->scrolling_list( -name => 'author',
                                        -Values => [sort {author_sort($auths{$a}, $auths{$b})} keys %auths],
#                                         -Values => [sort numerically keys %auths],
                                        -labels => \%auths, -size=>$size)),
                $f->p(
                    $f->submit(-name=>'submit',
                               -value=>'Show works by this author')));
    }
    
    $my_footer->();
    
    sub author_sort
    {
        my ($a, $b) = @_; 
        $a =~ tr/a-zA-Z//cd;
        $b =~ tr/a-zA-Z//cd;
        return (uc $a cmp uc $b);
    }
};

$handler{browser_authors} = sub { $output{browser_works}->(); };

$output{browser_works} = sub 
{
    my %args = $get_args->();
    my $q = new Diogenes::Browser::Stateless(%args);
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes Work Browser');
    $print_header->();
    $st{current_page} = 'browser_works';
    
    my %works = $q->browse_works( $st{author} );
    $strip_html->(\$_) for (values %works, keys %works);
    
    if (keys %works == 0) 
    {
        print $f->p($f->strong('Sorry, no matching names'));
    }
    elsif (keys %works == 1) 
    {
        my $work = (keys %works)[0];
        
        print
            $f->center(
                $f->p( 'There is only one work by this author:'),
                $f->p( $works{$work} ),
                $f->submit( -name => 'submit',
                            -value => 'Find a passage in this work'));
        $st{work} = $work;
    }
    else 
    {
        print
            $f->center(
                $f->p('Here is a list of works by your author.'),
                $f->p('Please select one.'),
                $f->p(
                    $f->scrolling_list( -name => 'work',
                                        -Values => [sort numerically keys %works],
                                        -labels => \%works)),
                $f->p(
                    $f->submit( -name => 'submit',
                                -value => 'Find a passage in this work')));
    }
    $my_footer->();
};

$handler{browser_works} = sub { $output{browser_passage}->() };


$output{browser_passage} = sub 
{
    my %args = $get_args->();
    my $q = new Diogenes::Browser::Stateless(  %args );
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes Passage Browser');
    $print_header->();
    $st{current_page} = 'browser_passage';
    
    print
        $f->center(
            $f->p(
                'Please select the passage you require by filling ',
                'out the following form with the appropriate numbers; ',
                'then click on the button below.'),
            $f->p(
                '(Hint: use zeroes to see the very beginning of ',
                'a work, including the title and proemial material.)'));
    
    print '<center><table><tr><td>';

    my @labels = $q->browse_location ($st{author}, $st{work});
    $st{levels} = $#labels;

    my $j = $#labels;
    foreach my $lev (@labels) 
    {
        my $lab = $lev;
        next if $lab =~ m#^\*#; 
        $lab =~ s#^(.)#\U$1\E#;
        print
            "$lab: ", '</td><td>', 
            $f->textfield( -default =>'0',
                           -name => "level_$j",
                           -size=>25 ),
            '</td></tr><tr><td>';
        $j--;
    }
    print
        '</td></tr><tr><td colspan=2>',
        $f->center(
            $f->p(
                $f->submit( -name => 'submit',
                            -Value => 'Show me this passage'))),
            '</table></center>';
    
    $my_footer->();

};

$handler{browser_passage} = sub { $output{browser_output}->() };
$handler{browser_output} = sub { $output{browser_output}->() };

$output{browser_output} = sub 
{
    my $jumpTo =  shift;
    my %args = $get_args->();
    my $q = new Diogenes::Browser::Stateless( %args );
    $database_error->($q) if not $q->check_db;
    
    my @target;
    $print_title->('Diogenes Browser');
    $print_header->();
    $st{current_page} = 'browser_output';

    if ($jumpTo)
    {
        if ($jumpTo =~ m/^([^,]+),\s*(\d+?),\s*(\d+?):(.+)$/) {
            my $corpus = $1;
            $st{author} = $2;
            $st{work} = $3;
            my $loc = $4;
            if ($loc =~ m/:/){
                @target = split(/:/, $loc);
            } else {
                push @target, $loc;
            }
             print STDERR "$jumpTo; $corpus, $st{author}, $st{work}, @target\n" if $q->{debug};
        }
        else {
            $print_error_page->("Bad location description: $jumpTo");
        }
        # Try to fix cases where we are not given the number of levels we expect
        $q->parse_idt($st{author});
        my $levels = scalar keys %{ $Diogenes::Base::level_label{$st{short_type}}{$st{author}}{$st{work}} };
        my $diff = $levels - scalar @target;
        print STDERR "**$levels**$diff**\n" if $q->{debug};
        if ($diff > 0) {
            while ($diff > 0) {
                push @target, 1;
                $diff--;
            }
        } elsif ($diff < 0) {
            while ($diff < 0) {
                pop @target;
                $diff++;
            }
        }
    }
    elsif (exists $st{levels})
    {
        for (my $j = $st{levels}; $j >= 0; $j--) 
        {
            push @target, $st{"level_$j"};
        }
    }
    
    if ($jumpTo or $previous_page eq 'browser_passage') 
    { 
        my ($begin_offset, $end_offset) = $q->seek_passage ($st{author}, $st{work}, @target);
        # When looking at the start of a work, don't browse back
        if (grep {!/^0$/} @target)
        {
            ($st{begin_offset}, $st{end_offset}) =
                $q->browse_half_backward($begin_offset, $end_offset, $st{author}, $st{work});
        }
        else
        {
            ($st{begin_offset}, $st{end_offset}) =
                $q->browse_forward($begin_offset, $end_offset, $st{author}, $st{work});
        }
    }   
    elsif ($st{browser_forward}) 
    {
        ($st{begin_offset}, $st{end_offset}) = $q->browse_forward ($st{begin_offset},
                                                                       $st{end_offset},
                                                                       $st{author}, $st{work});
    }
    elsif ($st{browser_back}) 
    {
        ($st{begin_offset}, $st{end_offset}) = $q->browse_backward ($st{begin_offset},
                                                                        $st{end_offset},
                                                                        $st{author}, $st{work});
    }
    else 
    {
        warn('Unreachable code!');
    }

    print
        $f->p($f->hr),
        $f->center(
            $f->p(
                $f->submit( -name => 'browser_back',
                            -value => 'Move Back'),
                $f->submit( -name => 'browser_forward',
                            -value=> 'Move Forward')));
           
    delete $st{browser_forward};
    delete $st{browser_back};
    
    $my_footer->();
};

############ Filters ###############

# @filters is an array of hash-refs, each of which have the keys
# "name", "type", and "authors".  The latter points to either an
# array-ref of author numbers (use the whole author) or a hash-ref
# whose keys are author numbers, and whose values are a ref to an
# array of work numbers.  Suitable for passing to
# select_authors(author_nums=>foo).

$output{filter_splash} = sub
{
    $st{current_page} = 'filter_splash';
    $print_title->('Diogenes Corpora');
    print
        $f->h1("Manage user-defined subsets of the databases."),

        $f->p('From this page you can create new corpora or subsets of the
        databases to search within, and you can also view and
        delete existing user-defined corpora.'),

        $f->p("Note that these user-defined corpora must be a subset
        of one and only one database; currently you cannot define a
        corpus to encompass texts from two different databases."),

        $f->p('Choose one of the options below.');


    print $f->h2('Define a simple new corpus'),

        $f->p(q(Enter a name or names or parts thereof, in order to
        narrow down the scope of your search within a particular
        database; you may separate multiple names by spaces or commas.
        When you proceed, this will bring you to another page where
        you can select which matching authors you wish to search in;
        you can then further narrow your selection down to particular
        works.));
    
    my $default_db;
    if ($st{database}) {
        # In case we have prompted the user for db path.
        $default_db = $st{database};
    } elsif ($st{corpus} and exists $choices{$st{corpus}}) {
        $default_db = $choices{$st{corpus}};
    } else {
        $default_db = 'tlg';
    }
    
    print
        $f->table({cellspacing=>'10px'},
                  $f->Tr(
                      $f->th({align=>'right'}, 'Author name(s): '),
                      $f->td(
                          $f->textfield( -name => 'author_pattern',
                                         -size => 60, -default => ''))),
                  $f->Tr(
                      $f->th({align=>'right'}, 'Database: '),
                      $f->td(
                          $f->popup_menu(
                              -name=>'database',
                              -Values=>\@databases,
                              -labels=>\%database,
                              -Default=>$default_db),
                          $f->submit( -name =>'simple',
                                      -value=>'Define subset' ))));

    print
        $f->h2('Define a complex subset of the TLG'),

        $f->p('The TLG classifies its texts into a large number of
        categories: chronological, generic, geographical, and so
        forth.  You can use these classifications to define a subset
        of works in the TLG to narrow down your search. '),
        
    $f->submit( -name => 'complex',
                -value => 'Define a complex TLG corpus');

    my $no_filters_msg = 'There are no saved texts';
    my $dis = '';
    $dis = '-disabled=>"true"' unless @filters;
    my @filter_names = ($no_filters_msg) unless @filters;
    push @filter_names, $_->{name} for @filters;
    
    
    print
        $f->h2('Manipulate an existing corpus'),

        $f->p('Select a previously defined corpus from the list below
        and choose an action.  '),

        $f->p( 'Corpus to operate on: ',
               $f->popup_menu( -name => 'filter_choice',
                               -values => \@filter_names,
                               $dis)),
        $f->p(
            $f->submit (-name=>'list',
                        -value=>'List contents'),
            $f->br,
            $f->submit (-name=>'delete',
                        -value=>'Delete entire corpus'),
            $f->br,
            $f->submit (-name=>'duplicate',
                        -value=>'Duplicate corpus under new name: '),
            $f->textfield( -name => 'duplicate_name',
                           -size => 60, -default => '')),

        $f->p('<strong>N.B.</strong> To delete items from a corpus,
        choose "List contents".  To add authors to an existing corpus,
        find the new authors using either the simple corpus or complex
        subset options above, and then use the name of the existing
        corpus you want to add them to.  The new authors will be
        merged into the old, but for any given author a new set of
        works will replace the old.  If you want to preserve the
        existing corpus and create a new one based on it, used the
        "Duplicate corpus" function first using a new name, and then
        add new authors to that. ');
    

    $my_footer->();
};

$handler{filter_splash} = sub
{
    if ($st{simple})
    {
        $output{simple_filter}->();
    }
    elsif ($st{complex})
    {
        $output{tlg_filter}->();
    }
    elsif ($st{list})
    {
        $output{list_filter}->();
    }
    elsif ($st{delete})
    {
        $output{delete_filter}->();
    }
    elsif ($st{duplicate})
    {
        $output{duplicate_filter}->();
    }
    else {
        $print_title->('Error');
        print $f->center($f->p($f->strong('Flow Error.')));
    }

};

$output{simple_filter} = sub
{
    my %args;
    $args{type} = $st{database};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    $args{user} = $user if $user;
    $st{short_type} = $st{database};
    $st{type} = $database{$st{database}};
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;   

    $print_title->('Diogenes Author Select Page');
    $print_header->();   
    $st{current_page} = 'simple_filter';

    my @auths = $q->select_authors(author_regex => $st{author_pattern});

    unless (scalar @auths)
    {
        print
            $f->p($f->strong('Error.')),
            $f->p(qq(There were no texts matching the author $st{author_pattern}));
        $my_footer->();
        return;
    }
    
    $f->autoEscape(undef);
    print $f->h1('Matching Authors'),

    $f->p('Here is a list of the authors that matched your query'),
    $f->p('Please select as many as you wish to search in, then go to
    the bottom of the page.');

    my @auth_nums = @{ $q->{prev_list} };
    my %labels;
    $labels{"$auth_nums[$_]"} = $auths[$_] for (0 .. $#auths);
    print $f->checkbox_group( -name => 'author_list',
                              -Values => \@auth_nums,
                              -labels => \%labels,
                              -linebreak => 'true' );

    print
        $f->p(
            $f->button( -value => "Select All",
                        -onClick => "setAll()" ),
            '&nbsp;&nbsp;&nbsp;&nbsp;',
            $f->reset( -value => 'Unselect All')),
        $f->p('&nbsp;');

    print $f->p('Please choose one of the following options before proceeding');

    my @values = qw(refine_works save_filter);
    my %radio_labels = ( save_filter =>
                         'Save the selected authors as a subset for later
use under this name:',
                         refine_works =>
                         'Further narrow down to particular works of
the selected authors' );
    my $default_choice = $st{simple_filter_option} || 'save_filter';

    my @group = $f->radio_group( -name => 'simple_filter_option',
                                 -values => \@values,
                                 -default => $default_choice,
                                 -labels => \%radio_labels );

    print $f->table(
        $f->Tr(
            $f->td( $group[0] )),
        $f->Tr(
            $f->td( $group[1] ),
            $f->td(
                $f->textfield( -name => 'saved_filter_name',
                               -size => 60,
                               -default => '' ))));

    print $f->p($f->submit( -name =>'Proceed'));

    $my_footer->();

};

my $save_filters = sub {
    open my $filter_fh, ">$filter_file"
        or die "Can't write to filter file ($filter_file): $!";
    print $filter_fh Data::Dumper->Dump([\@filters], ['*filters']);
    close $filter_fh or die "Can't close filter file ($filter_file): $!";
};

my $go_splash = sub {
    $output{filter_splash}->();
};

my $save_filters_and_go = sub {
    $save_filters->();
    %st = ();
    $go_splash->();
};

my $merge_filter = sub {
    my $new = shift;
    my $name = $new->{name};
    $print_error_page->('You must give your corpus a name!') unless ($name and $name =~ m/\S/);
    my $merge;
    for my $f (@filters) {
        if ($f->{name} eq $name) {
            unless ($f->{type} eq $new->{type}) {
                $print_error_page->("Cannot merge two corpora of different type!\n");
            }
            $merge = 1;
            my %tmp;
            if (ref($f->{authors}) eq 'ARRAY' and ref($new->{authors}) eq 'ARRAY') {
                $f->{authors} = [@{ $f->{authors} }, @{ $new->{authors} }];
            }
            elsif (ref($f->{authors}) eq 'HASH' and ref($new->{authors}) eq 'ARRAY') {
                $tmp{$_}++ for @{ $new->{authors} };
                $f->{authors} = { %{ $f->{authors} }, %tmp };
            }
            elsif (ref($f->{authors}) eq 'ARRAY' and ref($new->{authors}) eq 'HASH') {
                $tmp{$_}++ for @{ $f->{authors} };
                $f->{authors} = { %tmp, %{ $new->{authors} } };
            }
            elsif (ref($f->{authors}) eq 'HASH' and ref($new->{authors}) eq 'HASH') {
                $f->{authors} = { %{ $f->{authors} }, %{ $new->{authors} } };
            }
            else {
                die "Unreachable code!";
            }
        }
    }
    unless ($merge) {
        push @filters, $new;
    }
};

$handler{simple_filter} = sub
{
    if ($st{simple_filter_option} eq 'save_filter') {
#         print STDERR Data::Dumper->Dump([\@filters], ['*filters']);

        $merge_filter->({ name => $st{saved_filter_name},
                          authors => $st{author_list},
                          type => $st{database} });
#         print STDERR Data::Dumper->Dump([\@filters], ['*filters']);

        $save_filters_and_go->();
    }
    elsif ($st{simple_filter_option} eq 'refine_works') {
        $output{refine_works}->();
    }
    else{
        $print_error_page->();
    }
};

$output{refine_works} = sub
{
    my %args = ( -type => $st{database},
                 -output_format => 'html',
                 -encoding => $default_encoding );
    $args{user} = $user if $user;
    my $q = new Diogenes::Search( %args );
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes Individual Works');
    $print_header->();
    $st{current_page} = 'select_works';
    print
        $f->h1('Individual Works'),
        $f->p('Select the works you wish to use for searching.');

    
    unless ($st{author_list})
    {
        print
            $f->p($f->strong('Error.')),
            $f->p(qq(You must select at least one author));
        $my_footer->();
        return;
    }
    my @auth_nums = @{ $st{author_list} };
    unless (scalar @auth_nums)
    {
        print
            $f->p($f->strong('Error.')),
            $f->p(qq(There were no texts matching the author $st{author_pattern}));
        $my_footer->();
        return;
    }


    for my $a (@auth_nums)
    {
        my @work_nums = ();
        my %labels = ();
        $q->parse_idt($a);
        my $author = $author{$q->{type}}{$a};
        $q->format_output(\$author, 'l', 1);

        print $f->h2($author);
        for my $work_num (sort numerically
                          keys %{ $work{$q->{type}}{$a} })
        {
            push @work_nums, $work_num;
            $labels{"$work_num"} = $work{$q->{type}}{$a}{$work_num};
        }
        $q->format_output(\$_, 'l', 1) for values %labels;
        $strip_html->(\$_) for values %labels;
        print $f->checkbox_group( -name => "work_list_for_$a",
                                  -Values => \@work_nums,
                                  -labels => \%labels,
                                  -linebreak => 'true' );
    }
    print
        $f->hr,
        $f->p('Please choose a name for this corpus before saving it.');

    my $default_filter_name = $st{saved_filter_name} || '';
    print
        $f->textfield( -name => 'saved_filter_name',
                       -size => 60,
                       -default => $default_filter_name ),
        $f->p('&nbsp;'),
        $f->p($f->submit( -name =>'Save'));

    $my_footer->();
};

$handler{select_works} = sub
{
    my $work_nums;
    for my $k (keys %st)
    {
        next unless $k =~ m/^work_list_for_/;
        my $auth_num = $k;
        $auth_num =~ s/^work_list_for_//;
        $work_nums->{$auth_num} = $st{$k};
    }
    $merge_filter->({ name => $st{saved_filter_name},
                      authors => $work_nums,
                      type => $st{database} });
    
    $save_filters_and_go->();
};

$output{tlg_filter} = sub
{
    my %args;
    $args{type} = $st{database};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    $args{user} = $user if $user;
    $st{short_type} = 'tlg';
    $st{type} = 'TLG Texts';
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes TLG Selection Page');
    $print_header->();
    
    $st{current_page} = 'tlg_filter';
    
    my %labels = %{ $q->select_authors(get_tlg_categories => 1) };
    my %nice_labels = ( 'epithet' => 'Author\'s genre',
                        'genre_clx' => 'Text genre',
                        'location'  => 'Location' );
    my $j = 0;
    
    print
        $f->h1('TLG Classification'),
        $f->p(
            'Here are the various criteria by which the texts contained in
         the TLG are classified.'),
        $f->p('You may select as many items as you like in each box.  Try holding down
               the control key to select multiple items.');
    print '<table border=0 cellpadding=10px><tr><td>';
    foreach my $label (sort keys %labels)
    {
        unshift @{$labels{$label}}, '--';

        next if $label eq 'date' or $label eq 'gender' or $label eq 'genre';
        $j++;
        print "<strong>$j. $nice_labels{$label}:</strong><br>";
        print $f->scrolling_list( -name => $label,
                                  -Values => \@{ $labels{$label} },
                                  -multiple => 'true',
                                  -size => 8,
                                  -Default => '--');
        print '</td><td>';
    }
    print '</td></tr><tr><td>';
    $j++;
    print
        "<strong>$j. Gender:</strong><br>",
        $f->scrolling_list( -name => 'gender',
                            -Values => \@{ $labels{gender} },
                            -multiple => 'true',
                            -Default => '--'),
        '</td><td>';
    $j++;
    print
        "<strong>$j. Name of Author(s):</strong><br>",
        $f->textfield(-name=>'author_regex', -size=>25),
        
        '</td><td>',
        '<TABLE border=0><TR><TD colspan=2>';
    $j++;
    print
        "<strong>$j. Date Range:</strong>",
        '</td></tr><tr><td>',
        "After &nbsp;",
        '</td><td>';
    my @dates = @{ $labels{date} };
    pop @dates while $dates[-1] =~ m/Varia|Incertum/;
    unshift @dates, '--';
    print
        $f->popup_menu( -name => 'date_after',
                        -Values => \@dates,
                        -Default => '--'),
        '</td><td rowspan=2>',
        $f->checkbox( -name =>'Varia',
                      -label => ' Include Varia and Incerta?'),
        
        '</td></tr><tr><td>',
        "Before ",
        '</td><td>',
        $f->popup_menu( -name => 'date_before',
                        -Values => \@dates,
                        -Default => '--'),
        
        '</td></tr></table></td></tr></table>',
        $f->p('You may select multiple values for as many ',
        'of the above criteria as you wish.'),
        $f->p(
            'Then indicate below how many of ',
            'the stipulated criteria a text must meet ',
            'in order to be included in the search.'),
        $f->p(
            "<p><strong>Number of criteria to match: </strong>");
    my @crits = ('Any', 2 .. --$j, 'All');
    print
        $f->popup_menu(-name=>'criteria',
                       -Values=>\@crits,
                       -Default=>$default_criteria),
        '&nbsp;',
        $f->submit(  -name => 'tlg_filter_results',
                     -value => 'Get Matching Texts');

        $my_footer->();   
};

$handler{tlg_filter} = sub
{
    $output{tlg_filter_results}->();
};

my $get_args_for_tlg_filter = sub
{
    my %args;
    $args{user} = $user if $user;
    for (qw(epithet genre_clx location gender))
    {
        next if not defined $st{$_} or $st{$_} eq '--';
        my $ref = ref $st{$_} ? $st{$_} : [ $st{$_} ];
        $args{$_} = [ grep {$_ ne '--'} @{ $ref } ];
    }
    for (qw(author_regex criteria))
    {
        $args{$_} = $st{$_} if $st{$_};
    }
    $args{criteria} = 1 if $args{criteria} =~ m/any/;
#       $args{criteria} = 6 if $args{criteria} eq 'All';
    my @dates;
    push @dates, $st{'date_after'};
    push @dates, $st{'date_before'};
    push @dates, 1, 1 if $st{'Varia'};

    @{ $args{date} } = @dates
        if @dates and (($st{'date_after'} ne '--')
                       and ($st{'date_before'} ne '--'));

    return %args;
};


$output{tlg_filter_results} = sub
{
    my %args;
    $args{type} = $st{database};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    $args{user} = $user if $user;
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;

    $print_title->('Diogenes TLG Select Page');
    $print_header->();
    
    $st{current_page} = 'tlg_filter_output';
    
    $f->autoEscape(undef);
    %args = $get_args_for_tlg_filter->();
    my @texts = $q->select_authors(%args);
    my %labels;
    $labels{$_} = $texts[$_] for (0 .. $#texts);

    unless (scalar @texts)
    {
        print
            $f->p($f->strong('Error.')),
            $f->p(qq(There were no texts matching the criteria you gave.'));
        $my_footer->();
        return;
    }

    print $f->h1('Matching Authors and/or Texts'),
        $f->p('Here is a list of the texts that matched your query.'),
        $f->p('Please select as many as you wish to search in' ,
              'and click on the button at the bottom.'),
    
        $f->checkbox_group(-name => 'works_list',
                           -Values => [0 .. $#texts],
                           -labels => \%labels,
                           -linebreak => 'true' );

    print
        $f->p(
            $f->button( -value => "Select All",
                        -onClick => "setAll()" ),
            '&nbsp;&nbsp;&nbsp;&nbsp;',
            $f->reset( -value => 'Unselect All')),
        $f->hr;

    print
        $f->p('Please choose a name for this corpus before saving'),
        $f->textfield( -name => 'saved_filter_name',
                       -size => 60,
                       -default => '' ),
        $f->p('&nbsp'),
        $f->p($f->submit( -name =>'Save'));

    $my_footer->();
    
};

$handler{tlg_filter_output} = sub
{
    my %args;
    $args{type} = $st{database};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    $args{user} = $user if $user;
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;

    %args = $get_args_for_tlg_filter->();
    
    () = $q->select_authors(%args);
    () = $q->select_authors(previous_list => $st{works_list});

    my $work_nums = $q->{req_authors};
    for my $k (keys %{ $q->{req_auth_wk} })
    {
        $work_nums->{$k} = [keys %{ $q->{req_auth_wk}{$k} }];
    }
    $merge_filter->({ name => $st{saved_filter_name},
                      authors => $work_nums,
                      type => $st{database} });
    $save_filters_and_go->();
};

$output{list_filter} = sub
{
    my $filter = $get_filter->($st{filter_choice});
    my $type = $filter->{type};
    $st{short_type} = $type;
    $st{type} = $database{$type};

    my %args = ( -type => $type );
    $args{user} = $user if $user;
    my $q = new Diogenes::Search( %args );
    $database_error->($q) if not $q->check_db;

    $print_title->('User-defined corpus listing');
    $print_header->();
    $st{current_page} = 'list_filter';
    
    my $work_nums = $filter->{authors};
    my @texts = $q->select_authors( -author_nums => $work_nums);
    my %labels;
    $labels{$_} = $texts[$_] for 0 .. $#texts;
        

    print
        $f->h2('User-defined corpus listing'),
        $f->p(qq(Here is the subset of the $type database named $st{filter_choice}:));
#               (join '<br />', @texts);
    print $f->checkbox_group( -name => "filter_list",
                              -Values => [0 .. $#texts],
                              -labels => \%labels,
                              -columns=>'1' );

    print
        $f->hr,
        $f->submit(-name=>'delete_items',
                   -value=>'Click here to delete selected items');
    $my_footer->();
};

$output{delete_filter} = sub {
    my $name = $st{filter_choice};
    my $i = 0;
    for (@filters) {
        if ($_->{name} eq $name) {
            splice @filters, $i, 1;
            $save_filters_and_go->();
            return;
        }
        $i++;
    }
    die ("Could not find filter $name to delete it!");
};

$handler{list_filter} = sub
{
    if ($st{delete_items}) {
        $output{delete_filter_items}->();
    }
    else {
        $print_title->('Error');
        print $f->center($f->p($f->strong('Flow Error.')));
    }
};

sub deep_copy {
    my $this = shift;
    if (not ref $this) {
      $this;
    } elsif (ref $this eq "ARRAY") {
        [map deep_copy($_), @$this];
    } elsif (ref $this eq "HASH") {
        +{map { $_ => deep_copy($this->{$_}) } keys %$this};
    } else { die "what type is $_?" }
}


$output{duplicate_filter} = sub {
    return if $get_filter->($st{duplicate_name});
    my $old_filter = $get_filter->($st{filter_choice});
    my $new_filter = deep_copy($old_filter);
    $new_filter->{name} = $st{duplicate_name};
    push @filters, $new_filter;
    $save_filters_and_go->();
};



$output{delete_filter_items} = sub {
    my $filter = $get_filter->($st{filter_choice});
    my $type = $filter->{type};
    my %args = ( -type => $type );
    $args{user} = $user if $user;
    my $q = new Diogenes::Search( %args );
    $database_error->($q) if not $q->check_db;
    my $work_nums = $filter->{authors};
    my @orig_texts = $q->select_authors( -author_nums => $work_nums);
    # Naughty -- we ought to expose this in the API
    my @list = @{ $q->{prev_list} };
    splice @list, $_, 1 for @{ $st{filter_list} };
    my %new_work_nums;
    for my $item (@list) {
        if (ref $item) {
            my ($auth, $wk) = @{ $item };
            next if $new_work_nums{$auth} and $new_work_nums{$auth} eq 'all';
            my @w = exists $new_work_nums{$auth} ? @{ $new_work_nums{$auth} } : ();
            push @w, $wk;
            $new_work_nums{$auth} = \@w;
        }
        else {
            $new_work_nums{$item} = 'all';
        }
    }
    $filter->{authors} = \%new_work_nums;
    $save_filters_and_go->();

};


sub numerically { $a <=> $b; }


my $mod_perl_error = sub 
{
    $print_title->('Error');
    print '<p><center><strong>Error</strong></center></p>',
    '<p>This CGI script is set up to expect to run under mod_perl, ',
    'and yet it seems not to be doing so.</p>',
    '<p>Either comment out the relevant line at the start of this script, ',
    'or fix your mod_perl configuration.<p> ',
    '<p>Here is the current environment: <p> ';
    print "<pre>\n";
    print map { "$_ = $ENV{$_}\n" } sort keys %ENV;
    print "</pre>\n";
    return;
};

# End of subroutine definitions -- here's where the dispatching gets done

# Flow control
# warn $previous_page;

if ($check_mod_perl and not $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/)
{
    $mod_perl_error->();
}
elsif ($f->param('JumpTo')) 
{
    # Jump straight to a passage in the browser
    my $jump = $f->param('JumpTo');
    $jump =~ m/^([^,]+)/;
    $st{short_type} = $1;
    $st{type} = $database{$1};
    $output{browser_output}->($jump);
}
elsif (not $previous_page) 
{
    # First time, print opening page
    $output{splash}->();
}
else
{
    # Data present, pass control to the appropriate subroutine
    if ($handler{$previous_page})
    {
        $handler{$previous_page}->();
    }
    else
    {
        $print_error_page->();
    }
}
