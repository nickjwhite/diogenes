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

use Data::Dumper;

use Diogenes::Base qw(%encoding %context @contexts %choices %work %author);
use Diogenes::Search;
use Diogenes::Indexed;
use Diogenes::Browser;

use strict;
use File::Spec::Functions qw(:ALL);

$Diogenes::Base::cgi_flag = 1;

# Force read of config files 
my $init = new Diogenes::Base(-type => 'none');

# These are the old config variables -- I don't feel like rewriting all
# of the places they appear, despite the bad OO hygiene.

my @choices = reverse sort keys %choices;
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

my $default_encoding = 'UTF-8';
my %format_choices;
$format_choices{$_} = $_ for $init->get_encodings;
$format_choices{$default_encoding} = "Default: $default_encoding";

my $default_criteria = $init->{default_criteria};

# This is the directory whence the decorative images that come with
# the script are served.
my $picture_dir = 'images/';

my $check_mod_perl = $init->{check_mod_perl};

my $version = $Diogenes::Base::Version;
my (%handler, %output, $filter_flag);

use CGI qw(:standard);
#use CGI;
use CGI::Carp 'fatalsToBrowser';
$ENV{PATH} = "/bin/:/usr/bin/";
$| = 1;

my $f = $Diogenes_Daemon::params ? new CGI($Diogenes_Daemon::params) : new CGI;

# We need to pre-set the encoding for the earlier pages, so that the right
# header is sent out the first time Greek is displayed
$f->param('greek_output_format', $default_encoding) unless
    $f->param('greek_output_format');

my $default_input = $f->param('input_method');
$default_input ||= ($init->{cgi_input_format} eq 'BETA code') ? 'Beta' : 'Perseus';

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

# Remember that this sets up a single namespace for all cgi
# parameters on all pages of the script, so be careful not to
# duplicate parameter names from page to page.

my %st;
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
        if ( scalar @tmp == 1 and not $r =~ /work_list_for|author_list|works_list/)
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
my $previous_page = $st{current_page};

my $essential_footer = sub
{
    $set_state->();
    print $f->end_form,
    $f->end_html;
};

my $my_footer = sub
{                                                       
    print $f->hr,
    $f->center(

        $f->p(qq(<font size="-1">All data is &copy; the <em>Thesaurus
        Linguae Graecae</em>, the Packard Humanities Institute and
        others.<br>The information in these databases is subject to
        restrictions on access and use; consult your license.  <br><a
        href="http://www.durham.ac.uk/p.j.heslin/Software/Diogenes/">Diogenes</a>
        (version $version) is <a
        href="http://www.durham.ac.uk/p.j.heslin/diogenes/license.html">&copy;</a>
        1999-2005 P.J. Heslin.  </font>)),

        $f->p('<a href="Diogenes.cgi" title="New Diogenes Search">New Search</a>'));
    $essential_footer->();
};


my $print_error_page = sub 
{
    print $f->start_html( -title =>'Diogenes Error Page',
                          -style => {-type=>'text/plain', -src=>'diogenes.css'}),
    $f->center(
        $f->p(
            'Sorry. You seem to have made a request that I do not understand.')),
    $f->end_html;

};

my $print_title = sub 
{
    my $title = shift;
    my $jscript = undef;

    if (my $js = shift)
    {
        $jscript=qq(
        function setAll() {
            with (document.form) {
                for (i = 0; i < elements.length; i++) {
                    if (elements[i].name == "$js") {
                        elements[i].checked = true;
                        elements[i].selected = true;
                    }
                }
            }
        })
    }
    print
        $f->start_html(-title=>$title,
                       -encoding=>$charset,
                       -script=>$jscript,
                       -style=>{ -type=>'text/css',
                                 -src=>'diogenes.css'},
                       -meta=>{'content' => 'text/html;charset=utf-8'}
        ),
        "\n",
        $f->start_form(-name=>'form', -id=>'form');
};

my $print_header = sub 
{
    print qq(
        <center>
          <p id="logo">
           <font size="-1">
             <a href="Diogenes.cgi" title="New Diogenes Search">
               <img src="${picture_dir}Diogenes_Logo_Small.gif" alt="Logo"
                height="38" width="109" align="center" hspace="24" border="0"
                />
               <br />
               New Search
             </a>
           </font>
         </p>
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
    $$ref =~ s/&#\d+;/ /g;
};

my $database_error = sub
{
    my $self = shift;
    $print_title->('Database Error');
#     if ($ENV{"Diogenes-Browser"}) {print "FOO!!!"}
    print qq(<center>
              <div style="display: block; width: 50%; text-align: center;">
                  <h2 id="database-error" type="$st{short_type}"
                      long-type="$st{type}">Error: Database not found</h2>
         </div>
         </center>
                );

    $st{current_page} = 'splash';
    $essential_footer->();
};

### Splash page

$output{splash} = sub 
{
    $print_title->('Diogenes');
    $st{current_page} = 'splash';
    
    print $f->center(
        $f->img({-src=>$picture_dir.'Diogenes_Logo.gif',
                 -alt=>'Diogenes', 
                 -height=>'137', 
                 -width=>'383'})),
        $f->start_form(-id=>'form');

    
    print $f->p('Welcome to Diogenes, a tool for searching and
browsing through databases of ancient texts',
                $Diogenes_Daemon::flag 
                ? ' (<a href="Settings.cgi">see current settings</a>). '
                : '. ');

    print $f->p('Please enter your query: either some Greek or Latin
to <strong>search</strong> for (<a href="Input_info.html">see
hints</a>), or the name of an author whose work you wish to
<strong>browse</strong> through.  Then select the database containing
the information you require.  Click below on &quot;Basic Search&quot;
to find a single word or phrase using your default settings.  Click on
&quot;Advanced Search&quot; to specify multiple non-contiguous words
or phrases, or to specify what subset of texts to search in, or to
specify what language to use.  Click on &quot;Browse Texts&quot; to
see the work of the author whose name you have given (or specify no
author at all to browse through a complete list).');

    print $f->center(
        $f->p(
            'Query: ', 
            $f->textfield(-name=>'query', -size=>29),
            '&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;',
            'Corpus: ',
            $f->popup_menu( -name =>'type',
                            -id=>'corpus_menu',
                            -Values =>\@choices,
                            -Default=>$default_choice)));
    print $f->p('&nbsp;');
    
    print $f->center(
        $f->p(
            $f->submit( -name =>'Search',
                        -value=>'Basic Search'),
            '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
            $f->submit( -name =>'Advanced',
                        -value=>'Advanced Search'),
            '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
            $f->submit( -name=>'Browse',
                        -value=>'Browse Texts')));
    print $f->p('&nbsp;');

    $my_footer->();
        
};

### Splash handler

$handler{splash} = sub
{
    my $long_type = $st{type};
    if ($choices{$long_type}) 
    {
        # Convert to abbreviated form
        $st{short_type} = $choices{$long_type};
    }
    else
    {
        $print_error_page->();
    }
    
    if ($st{Search} and not $st{query})
    {
        print $f->center($f->p($f->strong('Error.')),
                         $f->p('You must specify a search pattern.'));
    }
    elsif ($st{Search}) 
    {
        $output{search}->();
    }
    elsif ($st{Advanced})
    {
        $output{advanced}->();
    }
    elsif ($st{Browse}) 
    {
        $output{browser}->();
    }
    else
    {
        print $f->center($f->p($f->strong('Flow Error.')));
    }
};

### Advanced search page

my $no_filters_msg = 'There are no saved texts';

my $read_filter_dir = sub
{
    my $dir = $init->{cgi_filter_dir};
    opendir(DIR, $dir) or die "can't opendir $dir: $!";
    my @filters = grep { /^[^.]/ and -f "$dir/$_" } readdir(DIR);
    closedir DIR;
    s/_/ /g for @filters;
    return grep {m/\.$st{short_type}$/} @filters;
};

$output{advanced} = sub 
{
    $print_title->('Diogenes Advanced Search Page');
    $print_header->();
    $st{current_page} = 'advanced';
    
    my $first_pattern = $st{query};

    print $f->h1($st{type}, ' Advanced Search Options');

    print $f->h2('Input Style');

    print $f->p('Here you can specify whether the search pattern(s)
    you enter should be interpreted as Latin or as transliterated
    Greek.  Usually you can just accept the default for this corpus,
    but sometimes you may wish to search for Greek text in a Latin
    corpus or vice versa.  If you are entering transliterated Greek,
    on the right you can override the default style as specified in your
    settings.');

    my $default_lang = 'Latin';
    $default_lang = 'Greek' if $st{type} =~ m/tlg text|tlg word|duke|greek|coptic/i;
    my %translit_labels =
        ( Perseus => 'Perseus-style Greek transliteration (no accents)',
          Beta => 'Beta code Greek transliteration (accents significant)' );
    print $f->table(
        $f->Tr(
            $f->td(
                $f->radio_group( -name => 'input_lang',
                                 -values => ['Latin', 'Greek'],
                                 -default => $default_lang,
                                 -columns=>1 )),
            $f->td('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'),
            $f->td('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'),
            $f->td(
                $f->radio_group( -name => 'input_method',
                                 -values => ['Perseus','Beta'],
                                 -default => $default_input,
                                 -columns => 1,
                                 -labels => \%translit_labels ))));


    print $f->hr, $f->h2('Multiple Patterns');

    print $f->p( 'If you wish to search for multiple, possibly
        non-contiguous words or phrases, a certain number of which
        must be found together within a particular scope, enter them
        here:');

    print 
        $f->textfield(-name=>'query1', -size=>50, -default=>$first_pattern),
        $f->br;

    my $fields = $init->{cgi_multiple_fields} || 6; 
    for (2 .. $fields)
    {
        print 
            $f->textfield(-name=>"query$_", -size=>50, -default=>''),
            $f->br;
    }
    
    my @matches = ('any', 2 .. 5, 'all');

    print $f->p( 'Define the scope within which these patterns are to
    be found together.  The number of lines is an exact measure,
    whereas the others depend on punctuation, which is guesswork.');

    print $f->p('Scope: ',
                $f->popup_menu( -name => 'context',
                                -Values => \@contexts,
                                -Default => 'sentence'));

    print $f->p('Define the minimum number of these patterns that must be
    present within a given scope in order to qualify as a successful
    match.');

    print $f->p('Quantity: ',
                $f->popup_menu( -name => 'min_matches',
                                -Values => \@matches,
                                -Default => 'all'));

    print $f->h3('Reject pattern'),

    $f->p('If there is a word or phrase whose presence in a given
    context should cause a match to be rejected, specify it here.');

    print $f->p('Reject: ',
                $f->textfield( -name => 'reject_pattern',
                               -size => 50,
                               -default => ''));

    print $f->hr, $f->h2('Which texts to search');

    print $f->p('Select one of the options below to proceed.'),
    $f->p(' The
    first option is not to limit the corpus at all but to search the
    whole thing.'),
    $f->p('The second option is to enter a name or names or parts
    thereof, in order to narrow down the scope of your search; you may
    separate multiple names by spaces or commas.  When you proceed,
    this will bring you to another page where you can select which
    matching authors you wish to search in; you can save this set of
    authors for later use.'),
    $f->p('The third option is to search within a set of
    texts that you selected previously and which have been saved for future
    use with the current corpus ('.$st{short_type}.').'),
    $f->p('The fourth option is to examine and manipulate the sets of saved
    search criteria');

    my @values = qw(search simple_filter use_saved_filter saved_filters);
    my %labels = ( search => 'Search full corpus',
                   simple_filter => 'Enter author name(s): ',
                   use_saved_filter => 'Use saved texts: ',
                   saved_filters => 'Manage saved texts',
        );
    my $default_choice = $st{proceed_to} || 'search';
    
    if ($st{type} =~ m/tlg/i)
    {
        print $f->p(' The last option is to proceed to a page where you
        can use a wide variety of criteria supplied by the <i>TLG</i>
        to narrow down the scope of your search, including genre,
        date, location, and so forth.');
        push @values, 'tlg_filters';
        $labels{tlg_filters} = 'Go to TLG categories';
    }

    my $default_filter = $st{saved_filter_choice};
    my @filters = $read_filter_dir->();
    
    @filters = ($no_filters_msg) unless @filters;
    
    
    my @group = $f->radio_group( -name => 'proceed_to',
                                 -values => \@values,
                                 -default => $default_choice,
                                 -labels => \%labels );
    print $f->table(
        $f->Tr(
            $f->td( $group[0] )),
        $f->Tr(
            $f->td( $group[1] ),
            $f->td(
                $f->textfield( -name => 'author_pattern',
                               -size => 60,
                               -default => ''))),
        $f->Tr(
            $f->td( $group[2] ),
            $f->td(
                $f->popup_menu( -name => 'saved_filter_choice',
                                -values => \@filters,
                                -default => $default_filter ))),
        $f->Tr(
            $f->td( $group[3] )),

        $group[4] ?
        $f->Tr(
            $f->td( $group[4] )) : '' );

    

    print $f->p(
        $f->submit( -name =>'Proceed'));
    
    $my_footer->();
};

$handler{advanced} = sub
{
    my $fields = $init->{cgi_multiple_fields} || 6; 
    delete $st{query_list};
    for (1 .. $fields)
    {
        if ($st{"query$_"} and $st{"query$_"} =~ m/\S/)
        {
            push @{ $st{query_list} }, $st{"query$_"};
        }   
        delete $st{"query$_"};
    }
    if (scalar @{ $st{query_list} } == 1)
    {
        $st{query} = $st{query_list}->[0];
        delete $st{query_list};
    }

    # output { search, use_saved_filter, simple_filter, or tlg_filter }
    $output{$st{proceed_to}}->();

};

$output{use_saved_filter} = sub
{
    if ($st{saved_filter_choice} eq $no_filters_msg)
    {
         $print_error_page->();
         return;
    }
    $filter_flag = 'saved_filter';
    $output{search}->();
};

$output{simple_filter} = sub
{
    $print_title->('Diogenes Author Select Page', 'author_list');
    $print_header->();
    
    $st{current_page} = 'simple_filter';
    my %args;
    $args{type} = $st{short_type};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;
    
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
        $f->hr;

    print $f->p('Please choose one of the following options before proceeding');

    my @values = qw(search saved_filters refine_works);
    my %radio_labels = ( search =>
                         'Just do a search over the selected authors',
                         saved_filters =>
                         'Save the selected authors as a set for later
use under this name:',
                         refine_works =>
                         'Further narrow down to particular works of
the selected authors' );
    my $default_choice = $st{simple_filter_option} || 'search';

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
                               -default => '' ))),
        $f->Tr(
            $f->td( $group[2] )));

    print $f->p($f->submit( -name =>'Proceed'));

    $my_footer->();
};

$handler{simple_filter} = sub
{
    # $output { search, saved_filters, refine_works }
    $filter_flag = 'simple_filter';
    $output{$st{simple_filter_option}}->();
};

my $get_args_for_tlg_filter = sub
{
    my %args;
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
    push @dates, $f->param('date_after') ;
    push @dates, $f->param('date_before') ;
    push @dates, 1, 1 if $f->param('Varia');

    @{ $args{date} } = @dates
        if @dates and (($f->param('date_after') ne '--')
                       and ($f->param('date_before') ne '--'));

    return %args;
};

# Take a query object and return contents of a saved filter, or the
# filter constituted by the parameters to the script.  Returns a
# hashref that can be used in select_authors.
my $get_filter = sub
{
    my $q = shift;
    my $file = shift;
    my $work_nums;
    if ($filter_flag eq 'saved_filter')
    {
        $file =  $st{saved_filter_choice} unless $file;
        my $path = catfile($init->{cgi_filter_dir}, $file);
        open my $filter, "<$path" or die "Can't open $path: $!";
        local $/ = undef;
        my %texts;
        my $code = <$filter>;
        eval $code;
        warn "Error reading in saved texts: $@" if $@;
        $work_nums = \%texts;
    }
    elsif ($filter_flag eq 'simple_filter')
    {
        $q->select_authors(author_regex => $st{author_pattern});
        $work_nums->{$_} = 1 for @{ $st{author_list} };
    }
    elsif ($filter_flag eq 'works_filter')
    {
        for my $k (keys %st)
        {
            next unless $k =~ m/^work_list_for_/;
            my $auth_num = $k;
            $auth_num =~ s/^work_list_for_//;
            $work_nums->{$auth_num} = $st{$k};
        }
    }
    elsif ($filter_flag eq 'tlg_filter')
    {
        my %args = $get_args_for_tlg_filter->();
        () = $q->select_authors(%args);

        my @auths = $q->select_authors(previous_list => $st{works_list});

        $work_nums = $q->{req_authors};
        for my $k (keys %{ $q->{req_auth_wk} })
        {
            $work_nums->{$k} = [keys %{ $q->{req_auth_wk}{$k} }];
        }
    }
    else
    {
        $print_error_page->();
    }
    return $work_nums;
};


$output{saved_filters} = sub
{
    $print_title->('Diogenes Managing Text Sets');
    $print_header->();
    $st{current_page} = 'managing_sets';
    print $f->h1(q(Manage Saved Text Sets.));

    if ($st{saved_filter_name})
    {
        my $file = $st{saved_filter_name};
        if (not $file or not $file =~ m/\w/)
        {

            print
                $f->p($f->strong('ERROR')),
                $f->p(q(You have not given a valid name for this set
                of texts.  Please go back and choose another name.));
            $my_footer->();
            return;
        }
        elsif ($file =~ m/[`~!@#\$%^&\*()\=+\\\|'";:,\.<>\/\?гд]/)
        {
            print
                $f->p($f->strong('ERROR')),
                $f->p(qq(You have used a funny symbol in the name you
                gave for this set of texts: $file.  Since this is used as a
                filename, that's not a good idea.  Please go back and
                choose another name));
            $my_footer->();
            return;
        }
        my $q = new Diogenes::Base( -type => $st{short_type} );
        $database_error->($q) if not $q->check_db;

        my $work_nums = $get_filter->($q);

        $file .= '.' . $st{short_type};
        my $path = catfile($init->{cgi_filter_dir}, $file);
        if (-e $path)
        {
            print
                $f->p($f->strong('ERROR')),
                $f->p(qq(You have used the same name as an existing file:
                $file.  You must choose a different name or explicitly delete the old file.));
            $my_footer->();
            return;
        }
        
        open my $NEWFILTER, ">$path" or die "Can't open $path: $!";
        print $NEWFILTER Data::Dumper->Dump([$work_nums], ['*texts']);
        close $NEWFILTER or die "Can't close $path: $!";

        print $f->hr,
            $f->p(qq(Your selected texts have been saved under the
            name $st{saved_filter_name} )),
            $f->hr;
    }

    print
        $f->h2('Sets'),

        $f->p('Here are the saved sets of texts that are available for
        use with the current corpus ('.$st{short_type}.'). 
        Use the buttons to view or delete any of them.  To
        perform a search, click on the buttons at the bottom.');

    my @filters = $read_filter_dir->();
    print q(<table>);
    for my $filter (@filters)
    {
        my $filter_file = $filter;
        $filter_file =~ s/ /_/g;
        print $f->Tr(
            $f->td($filter),  '&nbsp;&nbsp;',
            $f->td($f->submit( -name => "view_filter_$filter_file",
                               -value => 'View' )),
            $f->td($f->submit( -name => "delete_filter_$filter_file",
                               -value => 'Delete' )));
    }
    print
        q(</table>),
        $f->hr(),

        $f->p(
            q(Click on the button below to return to the advanced
            search options page, where you can select any of the
            text sets listed above to use in a search.)),
            
        $f->submit( -name => 'proceed_back_to_advanced',
                    -value => 'Return to Searching');
    $my_footer->();
};

$handler{managing_sets} = sub
{
    delete $st{saved_filter_name};
    for my $p (keys %st)
    {
        if ($p =~ m/^view_filter/)
        {
            my $filter = $p;
            $filter =~ s/^view_filter_//;

            $filter_flag = 'saved_filter';
            my $q = new Diogenes::Base( -type => $st{short_type} );
            $database_error->($q) if not $q->check_db;
            my $work_nums = $get_filter->($q, $filter);
            my @texts = $q->select_authors( -author_nums => $work_nums);
        
            $filter =~ s/_/ /g;
            print
                $f->h2('Content'),
                $f->p(qq(Here is the content of the set of texts called
                $filter.) ),
                (join '<br />', @texts);
            
            delete $st{$p};
            $my_footer->();
            return;
        }
        elsif ($p =~ m/^delete_filter/)
        {
            my $filter = $p;
            $filter =~ s/^delete_filter_//;
            my $path = catfile($init->{cgi_filter_dir}, $filter);
            unlink($path) or die "Can't unlink $path: $!";
            $filter =~ s/_/ /g;
            delete $st{$p};
            $output{saved_filters}->();
            return; 
        }
    }
    $output{advanced}->();

};

$output{refine_works} = sub
{
    $print_title->('Diogenes Individual Works', 'works_list');
    $print_header->();
    $st{current_page} = 'select_works';
    print
        $f->h1('Individual Works'),
        $f->p('Select the works you wish to use for searching.');
    
    my $q = new Diogenes::Search( -type => $st{short_type},
                                  -output_format => 'html',
                                  -encoding => $default_encoding );
    $database_error->($q) if not $q->check_db;

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
        print $f->h2($author);
        for my $work_num (sort numerically
                          keys %{ $work{$q->{type}}{$a} })
        {
            push @work_nums, $work_num;
            $labels{"$work_num"} = $work{$q->{type}}{$a}{$work_num};
        }
        unless (scalar @work_nums == 1)
        {
            push @work_nums, 'ALL';
            $labels{'ALL'} = q{Include all of this author's works};
        }
        print $f->checkbox_group( -name => "work_list_for_$a",
                                  -Values => \@work_nums,
                                  -labels => \%labels,
                                  -linebreak => 'true' );
    }
    print
        $f->hr,
        $f->p('Please choose one of the following options before proceeding');

    my @values = qw(search saved_filters);
    my %radio_labels = ( search =>
                         'Just do a search over the selected works',
                         saved_filters =>
                         'Save the selected works as a set for later
use under this name:');
    my $default_choice = $st{works_filter_option} || 'search';

    my @group = $f->radio_group( -name => 'works_filter_option',
                                 -values => \@values,
                                 -default => $default_choice,
                                 -labels => \%radio_labels );
    my $default_filter_name = $st{saved_filter_name} || '';
    print $f->table(
        $f->Tr(
            $f->td( $group[0] )),
        $f->Tr(
            $f->td( $group[1] ),
            $f->td(
                $f->textfield( -name => 'saved_filter_name',
                               -size => 60,
                               -default => $default_filter_name ))));

    print $f->p($f->submit( -name =>'Proceed'));

    $my_footer->();
};

$handler{select_works} = sub
{
    # $output { search, saved_filters }
    $filter_flag = 'works_filter';
    $output{$st{works_filter_option}}->();
    
};

$output{tlg_filters} = sub
{
    $print_title->('Diogenes TLG Selection Page', 'author_list');
    $print_header->();
    
    $st{current_page} = 'tlg_filters';
    my %args;
    $args{type} = $st{short_type};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;
    
    my %labels = %{ $q->select_authors(get_tlg_categories => 1) };
    my %nice_labels = ( 'epithet' => 'Author\'s genre',
                        'genre_clx' => 'Text genre',
                        'location'  => 'Location' );
    my $j = 0;
    
    print
        $f->p(
            'Here are the various criteria by which the texts contained in
         the TLG are classified.'),
        $f->p('You may select as many items as you like in each box.  Try holding down
               the control key to select multiple items.');
    print '<table border=0><tr><td>';
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
        '</td><td colspan=2>';
    $j++;
    print
        "<strong>$j. Name of Author(s):</strong><br>",
        $f->textfield(-name=>'author_regex', -size=>25),
        
        '</td></tr></table>',
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
        
        '</td></tr></table>',
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

$handler{tlg_filters} = sub
{
    #FIXME
    # $output { search, saved_filters, refine_works }
    $filter_flag = 'tlg_filter';
#     print STDERR "foo";
    $output{tlg_filter_results}->();
};



$output{tlg_filter_results} = sub
{
    $print_title->('Diogenes TLG Select Page', 'works_list');
    $print_header->();
    
    $st{current_page} = 'tlg_filter_output';
    my %args;
    $args{type} = $st{short_type};
    $args{output_format} = 'html';
    $args{encoding} = $default_encoding;
    my $q = new Diogenes::Search(%args);
    $database_error->($q) if not $q->check_db;

    %args = $get_args_for_tlg_filter->();
    
    $f->autoEscape(undef);
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

    print $f->p('Please choose one of the following options before proceeding');

    my @values = qw(search saved_filters);
    my %radio_labels = ( search =>
                         'Just do a search over the selected items',
                         saved_filters =>
                         'Save the selected authors as a set for later
use under this name:');
    my $default_choice = $st{simple_filter_option} || 'search';

    my @group = $f->radio_group( -name => 'tlg_filter_output_option',
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
                               -default => '' ))),
        $f->Tr(
            $f->td( $group[2] )));

    print $f->p($f->submit( -name =>'Proceed'));

    $my_footer->();
    
};

$handler{tlg_filter_output} = sub
{
    # $output { search, saved_filters, refine_works }
    $filter_flag = 'tlg_filter';
    $output{$st{tlg_filter_output_option}}->();
};


my $get_args = sub
{
    my %args = (
        type => $st{short_type},
        output_format => 'html',
        highlight => 1,
        );
    $args{input_beta} = 1 if (exists $st{input_method}
                              and $st{input_method} =~ m/beta/i);
    $args{input_lang} = $st{input_lang} ? $st{input_lang} : $st{type} =~ m/Latin/i ? 'l' : 'g';
    $args{perseus_links} =  $st{perseus_links} if exists $st{perseus_links};

    # These don't matter for indexed searches
    if (exists $st{query_list})
    {
        $args{pattern_list} = $st{query_list};
    }
    else
    {
        $args{pattern} = $st{query};
    }
    
    for my $arg qw(context min_matches reject_pattern)
    {
        $args{$arg} = $st{$arg} if $st{$arg};
    }
    $args{context} = '2 lines' if $st{type} =~ m/inscriptions|papyri/i
                               and not exists $st{context};

    $args{encoding} = $st{greek_output_format} || $default_encoding;
    
    return %args;
};

my $show_filter = sub
{
    my $q = shift;
    if ($filter_flag)
    {

        my $filter = $get_filter->($q);
        my @texts = $q->select_authors( -author_nums => $filter);
        
        print
            $f->p('Searching in the following: '),
            (join '<br />', @texts),
            $f->hr;
    }
};


$output{indexed_search} = sub 
{
    
    $print_title->('Diogenes TLG word list result', 'word_list');
    $print_header->();
    $st{current_page} = 'word_list';
    my @params = $f->param;
    
    my %args = $get_args->();
    my $q = new Diogenes::Indexed(%args);
    $database_error->($q) if not $q->check_db;

    $show_filter->($q);

    # Since this is a 2-step search, we have to save it.
    $st{saved_filter_flag} = $filter_flag if $filter_flag;

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

    $print_title->('Diogenes Search');
    $print_header->();
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

    $show_filter->($q);

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



my $process_perseus_toggle = sub
{
    if ($st{add_perseus_links})
    {
        $st{perseus_links} = 1;
        delete $st{add_perseus_links};
    }
    elsif ($st{remove_perseus_links})
    { 
        $st{perseus_links} = 0;
        delete $st{remove_perseus_links};
    }

};

$handler{doing_search} = sub
{
    $process_perseus_toggle->();
    # Check to see if we are switching to the browser
    if (grep m/^GetContext/, keys %st)
    {
        $output{browser_output}->();
    }
    else
    {
        warn("Unreachable code!");
    }
};


$output{browser} = sub 
{
    $print_title->('Diogenes Author Browser');
    $print_header->();
    $st{current_page} = 'browser_authors';

    my %args = $get_args->();

    my $q = new Diogenes::Browser::Stateless(%args);
    $database_error->($q) if not $q->check_db;

    my %auths = $q->browse_authors($st{query});

    # Because they are going into form elements, and most browsers
    # do not allow HTML there.
    $strip_html->(\$_) for values %auths;

    if (keys %auths == 0) 
    {
        print
            $f->p($f->strong('Sorry, no matching names')),
            $f->p(
                'To browse texts, enter part of the name of the author ',
                'or corpus you wish to examine.<p>  Remember to specify the ',
                'correct database and note that capitalization ',
                'of names is significant.');
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
    $print_title->('Diogenes Work Browser');
    $print_header->();
    $st{current_page} = 'browser_works';
    
    my %args = $get_args->();
    
    my $q = new Diogenes::Browser::Stateless(%args);
    $database_error->($q) if not $q->check_db;

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
                $f->submit( -name => 'work',
                            -value => 'Find a passage in this work'));
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
    $print_title->('Diogenes Passage Browser');
    $print_header->();
    $st{current_page} = 'browser_passage';
    my %args = $get_args->();
    
    my $q = new Diogenes::Browser::Stateless(  %args );
    $database_error->($q) if not $q->check_db;

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
    $print_title->('Diogenes Browser');
    $print_header->();
    $st{current_page} = 'browser_output';
    
    my %args = $get_args->();
    
    my $q = new Diogenes::Browser::Stateless( %args );
    $database_error->($q) if not $q->check_db;
    
    my @target;
    if (exists $st{levels})
    {
        for (my $j = $st{levels}; $j >= 0; $j--) 
        {
            push @target, $st{"level_$j"};
        }
    }
    
    if ($previous_page eq 'browser_passage') 
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
    elsif (my @array = grep {m/^GetContext/} keys %st) 
    {
        # Set up the browser if we have come from a search result
        my $param = pop @array;
        $param =~ s#^GetContext~~~##;
        my ($auth, $work, $beginning) = split(/~~~/, $param);
        ($st{begin_offset}, $st{end_offset}) = $q->browse_forward ($beginning, -1, $auth, $work);
        $st{author} = $auth;
        $st{work} = $work;
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

sub numerically { $a <=> $b; }


###################################################################
#                                                                 #
# Page 1 is the opening page, with choice of general search type  #
#                                                                 #
###################################################################

my $mod_perl_error = sub 
{
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

# HTML output
print $f->header(-type=>"text/html; charset=$charset");

# Flow control
# warn $previous_page;

if ($check_mod_perl and not $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/)
{
    $mod_perl_error->();
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
