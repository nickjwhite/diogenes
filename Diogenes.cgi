#!/usr/bin/perl -w
##########################################################################
#                                                                        #
# Diogenes is a set of programs including this CGI script which provides #
# a graphical interface to the CD-Rom databases published by the         #
# Thesaurus Linguae Graecae and the Packard Humanities Institute.        #
#                                                                        #
# Copyright P.J. Heslin 1999 - 2001.                                     #
# Diogenes comes with ABSOLUTELY NO WARRANTY;                            #
# for details see the file named COPYING.                                #
#                                                                        #
##########################################################################

# Nota Bene:
#
# Prior to version 0.9, there were a whole series of configuration
# settings to be edited here.  These have all been moved out into the
# configuration files, in order to be able to generate them at install
# time for MS Windows users.

##########################################################################

use Diogenes 0.9;
use strict;
$Diogenes::cgi_flag = 1;

# Force read of config files 
my $init = new Diogenes(-type => 'none');

# These are the old config variables -- I don't feel like rewriting all
# of the places they appear, despite the bad OO hygiene.

my @choices = reverse sort keys %Diogenes::choices;
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
my %format_choices;
$format_choices{$_} = $_ for $init->get_encodings;
$format_choices{$default_encoding} = "Default: $default_encoding";
$format_choices{'latex'} = 'GIFs via LaTeX' if $init->{cgi_enable_latex};
$format_choices{'latex_postscript'} = 'PostScript' if $init->{cgi_enable_latex};
$format_choices{'pdf'} = 'PDF via LaTeX' if $init->{cgi_enable_latex};
# $format_choices{'ibycus'} = 'Latin transliteration';

my $tmp_dir = $init->{cgi_tmp_dir};
my $prefix =  $init->{cgi_prefix};
my $tmp_prefix = $tmp_dir.$prefix;
my $default_criteria = $init->{cgi_default_criteria};

my $Img_dir = $init->{cgi_img_dir_absolute};

# Note the lower-case i
my $img_dir = $init->{cgi_img_dir_relative};

#####################################################################
#                                                                   #
# This is the directory whence the pointless decorative images      #
# that come with the script are served.  It can safely be the same  #
# directory as $img_dir above (also ends with a /).                 #

my $picture_dir = $img_dir;

my $GS = $init->{cgi_gs};
my $p2g =$init->{cgi_p2g};
my $latex = $init->{cgi_latex};
my $ps2pdf = $init->{cgi_ps2pdf};
my $dvips = $init->{cgi_dvips};

my $check_mod_perl = $init->{cgi_check_mod_perl};
my $cgi_latex_word_list = $init->{cgi_latex_word_list};
################### End of Configuration Section#####################

use CGI qw(:standard);
#use CGI;
use CGI::Carp 'fatalsToBrowser';
delete @ENV{qw(IFS CDPATH ENV BASH_ENV HOME)};   # Make %ENV safer
$ENV{PATH} = "/bin/:/usr/bin/";
$| = 1;

my $gs_args = '-sDEVICE=ppmraw -q -dNOPAUSE -dNO_PAUSE -dTextAlphaBits=4 ';
my $session = unpack ("H*", pack ("Nn", time, $$)); # 12 hex digit session ID
my $TMP = $tmp_prefix.$session.'_';

my $form = $Diogenes_Daemon::params ? new CGI($Diogenes_Daemon::params) : new CGI;

# We need to pre-set the encoding for the earlier pages, so that the right
# header is sent out the first time Greek is displayed
$form->param('greek_output_format', $default_encoding) unless
                $form->param('greek_output_format');

my $default_input = $form->param('Input_method');
$default_input ||= ($init->{cgi_input_format} eq 'BETA code') ? 'Beta' : 'Perseus';


########################## NOTA BENE ###################################
# Processing of the form starts at the end of this file; first we have #
# to declare all our subs as anon (closures) for mod_perl and          #
# diogenes_daemon re-entrancy hygiene.                                 #
########################################################################

my %handler; my $query;

my $my_footer = sub
{							
	print <<"END";
<p><hr>
<center>	
<p><FONT SIZE="-1">All data is &copy; the <em>Thesaurus Linguae
Graecae</em>, the Packard Humanities Institute and others.<br>The information in
these databases is subject to restrictions on access and use; consult your license.
<br><a href="http://www.durham.ac.uk/p.j.heslin/diogenes">Diogenes</a>
(version $Diogenes::VERSION) is 
<a
href="http://www.durham.ac.uk/p.j.heslin/diogenes/license.html">&copy;</a>
1999-2001 P.J. Heslin. 
</FONT>
<p>    
<a href="Diogenes.cgi" title="New Diogenes Search">New Search</a>
</CENTER>
END
	print $form->end_form,
		  $form->end_html;
};

my $style =<<'END';
<!-- A:link {text-decoration: none}A:visited{text-decoration:none}A:active{text-decoration:none}-->
END


my $print_error_page = sub 
{
	print $form->start_html(-title   =>'Diogenes Error Page',
							-bgcolor =>'#FFFFFF',
							-text  	 =>"#000000", 
							-link    =>"#0000ee", 
							-vlink	 =>"#ff0000", 
							-alink	 =>"#000099" ),
	
		'<center>Sorry. You seem to have made a request that I do not
		understand.</center>',
		$form->end_html;

};

my $print_no_database = sub 
{
    my $errstr = shift;
	print '<center><b>Error.<br> The requested database was not found.</b>',
        '<p>It may be that Diogenes has not been configured properly, ',
        'or it may be that the device was not ready.',
        '<p>',
        "I looked for the database here:<br>$errstr<br>",
        'Is that information correct?  If not, you will have to fix your ',
        'configuration file.',
        '</center><p>', 
        $form->end_html;
        die "Database not found\n";
};

my $print_title = sub 
{
	my $title = shift;
	my $jscript = undef;
  	my $font_spec = '';
  	$font_spec = '<FONT FACE="'.$init->{unicode_font}.'">' if $init->{unicode_font}
            and $form->param('greek_output_format') 
            and not $Diogenes::encoding{$form->param('greek_output_format')}{font_name}
    # Trade-off: many unicode fonts don't have italics, which are nice for
    # Latin
            and defined $form->param('Type')
            #and $Diogenes::choices{$form->param('Type')} ne 'phi';
            and $form->param('Type') !~ m/phi|misc/i;



	if (my $js = shift)
	{
		$jscript=<<"END";
    function setAll() {
      with (document.form) {
        for (i = 0; i < elements.length; i++) {
          if (elements[i].name == "list_$js") {
            elements[i].checked = true;
            elements[i].selected = true;
          }
        }
      }
    }
END

	}
	print $form->start_html(-title=>$title,
				-script=>$jscript,
				-bgcolor=>'#FFFFFF', -text=>"#000000", -link=>"#0000ee", 
				-vlink=>"#ff0000", alink=>"#000099",
				-style=>{-type=>'text/css', -code=>$style}), "\n",
		$form->start_form(-name=>'form'),
        "\n$font_spec\n";
};

my $print_header = sub 
{
	print<<"END";
<center><font size="-1">
<a href="Diogenes.cgi" title="New Diogenes Search">
<img src="${picture_dir}Diogenes_Logo_Small.gif"
	 alt="Logo" height="38" width="109" align="center" 
	 hspace="24" border="0"><br>New Search</a>
</font></center><p>
END

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

#################
#               #
# Splash page!  #
#               #
#################

my $print_splash_page = sub 
{
	$print_title->('Diogenes');
		
    print "\n<CENTER>",
		$form->img({src=>$picture_dir.'Diogenes_Logo.gif',
					alt=>'Diogenes', 
					height=>'137', 
					width=>'383'}),
		"</CENTER>\n",
		$form->start_form;

	$form->param('current_page','1');
	print $form->hidden('current_page');
	# The default
	$form->param('greek_output_format', $default_encoding);
	print $form->hidden('greek_output_format');
	
	print '
<p>';

    print 'Welcome to Diogenes, a tool for searching and browsing through 
databases of ancient texts';

    print $Diogenes_Daemon::flag 
    ? ' (<a href="Settings.cgi">see current settings</a>). '
    : '. ';

    print 'Please enter your query: either some 
Greek or Latin to <strong>search</strong> for
(<a href="Input_info.html">see hints</a>),
or the name of an author
whose work you wish to <strong>browse</strong> through.
Then select the database containing the
information you require.  Click below on 
&quot;Search&quot; if you have entered a word to find
or &quot;Browse&quot; if you have entered the name of an author 
(or specify no author at all to browse through a complete list).
</p>
<p><center><TABLE border=0><TR><TD><table border=0><tr><td align="right">
  Query: </td><td align="left">', 
  $form->textfield(-name=>'query', -size=>29), 
  '</td></tr><tr><td>&nbsp;</td></tr><tr><td align="right">
  Corpus: </td><td align="left">',
	$form->popup_menu(  -name   =>'Type',
							-Values =>\@choices,
							-Default=>$default_choice),
  '</td></tr>
</table></TD><TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD><TD><table border=0>
  <tr><td>',
		$form->checkbox(	-name=>'Filter',
							-label=>' Specify which texts to search through'),
  '</td></tr>
  <tr><td>',
  
		$form->checkbox(	-name=>'Multiple',
							-label=>' Enter more than one search pattern'),
  '</td></tr><tr><td>&nbsp;</td></tr>
  <tr><td>',
        $form->radio_group(-name=>'Input_method',
                                    -values=>['Perseus','Beta'],
                                    -default=>$default_input,
                                    -columns=>1,
                                    -labels=>{Perseus=>'Perseus-style Greek transliteration (no accents)  ', 
											  Beta=>'Beta code Greek input (accents significant)'}),
'</td></tr>
</table></TD></TR><TR><TD>&nbsp;</TD></TR><TR><TD align="right">', 
   $form->submit(			-name =>'Go',
							-value=>'Search'),
  
  '</TD><TD>&nbsp;</TD><TD>',
							
  $form->submit(			-name=>'Browse',
							-value=>'Browse'),
  '</TD></TR></TABLE></center>';
	$my_footer->();
	
};


my $print_page_2 = sub 
{
	$print_title->('Diogenes Multiple Pattern Page');
	$print_header->();
	$form->param('current_page', '1');
	$form->param('Multiple', 'Done');
	print $form->hidden('current_page'),
		 $form->hidden('Type'),
		 $form->hidden('Filter'),
		 $form->hidden('Multiple'),
		'<center><TABLE BORDER=0><TR><TD>';
	
	# Add queries
	my $new_pattern = $form->param('query');
	my @patterns = $form->param('query_list');
	@patterns = () unless @patterns;
	push @patterns, $new_pattern if $new_pattern;
	$form->param(-name=>'query_list', -values=>\@patterns);	
	print $form->hidden('query_list');
	
	if (@patterns)
	{
		print '<h3>Here is a list of the patterns you have entered thus far:</h3>',
			  '<p><ol>';
		print "<li>$_</li>\n" foreach @patterns;
		print '</ol></p><hr>';
	}
	
	print '<h3>You may add a' . (@patterns ? 'nother' : '') . ' pattern:</h3>',
	      '<center>',
		  '<p>',
#		  '<INPUT type=text value="" framewidth=4 name=query size=40></p>',
  		  $form->textfield(-name=>'query', -size=>25, -default=>'',
                           -override=>1),
		  '<p>',
		  $form->submit(-name=>'Add_Pattern',
						-value=>'Add this pattern to the list'),
		  '</p></center>';

	my @matches = ('any', 2 .. $#patterns, 'all');
					
	print '<hr><h3>Define type of search:</h3>',
		  '<p>Find passages containing ',
		  $form->popup_menu(-name   =>'Min_Matches',
							-Values =>\@matches,
							-Default=>'all'),
		  ' of these patterns within the space<br>of ',
		  $form->popup_menu(-name   =>'Context',
							-Values =>\@Diogenes::contexts,
							-Default=>'sentence'),
		  'in the ', $form->param('Type'), '.</p>',
	      '<hr><h3>Reject pattern:</h3>',
          '<p>Do not display passages matching the following pattern: <p><center>',
  		  $form->textfield(-name=>'Reject', -size=>25, -default=>''),
		  '<hr><p>',
		  $form->submit(	-name	=>'Just_Go',
							-value	=>'Do search'),
		  '</center>',
		  '</TD></TR></TABLE></center>';
	$my_footer->();
};


my $encoding_footer = sub
{
    if ($form->param('Type') =~ m/cop/i)
    {
        $my_footer->();
        return;
    }
        
	my $out_form = $form->param('greek_output_format');
	$out_form ||= $default_encoding;
	print $form->hr,
		  '<center><TABLE border=0><TR><TD><center>',
		  '<p>Current Greek encoding: ',
		  $out_form,
		  $form->p;
	
	print $form->popup_menu(-name =>'greek_output_format',
							-values=>[sort keys %format_choices],
							-default=>$default_encoding,
							-labels=>\%format_choices);
								
	print $form->submit(	-name =>'Reformat Greek',
		 					-value=>'Reformat');
    unless ($init->{perseus_links})
    {
        print $form->p, $form->checkbox(-name=>'add_perseus_links',
                                  -checked=>0,
                                  -value=>'ON',
                                  -label=>' Add links to Perseus morphological analysis? ');
	}
	print '</CENTER></TABLE></center>';

	$my_footer->();
};
########################################################
#                                                      #
# Page 3 does a non-TLG search and prints the results. #
#                                                      #
########################################################
my $print_page_3 = sub 
{
	
	$print_title->('Diogenes Search');
	$print_header->();
	$form->param('current_page', '6');
	print $form->hidden('current_page');
	print $form->hidden('Type');
	
	my %args;
	
	$args{output_format} = 'html'; 
	$args{highlight} = 1;
	
	$args{type} = $Diogenes::choices{$form->param('Type')};
	die "What sort of search is this?" unless $args{type};
	
	$args{input_beta} = 1 if ($default_input =~ m/beta/i);
    $args{input_lang} = 'g';
    $args{input_lang} = 'l' if $form->param('Type') =~ m/Latin/i;
	
	my @pattern = $form->param('query_list');
	@pattern 	= ($form->param('query')) unless @pattern;
	$args{pattern_list} = \@pattern;
	
	if ($form->param('Multiple'))
	{
		$args{min_matches}  = $form->param('Min_Matches');
		$args{context}		= $form->param('Context');
        $args{reject_pattern} = $form->param('Reject') if $form->param('Reject');
	}
    else
    {
		$args{context}	= 'sentence';
		$args{context}	= '2 lines' if $form->param('Type') =~ m/inscriptions|papyri/i;
;
    }
	my $aux_file = $TMP;
	chop $aux_file;
	$aux_file = ">$aux_file.bta";
	
	open OUT, $aux_file or die ("Can't open $aux_file: $!");
	binmode OUT;
	$args{aux_out} = \*OUT;
	$query = new Diogenes(%args);
    $print_no_database->($query) if not ref $query;
	
	if ($form->param('Filter') and $form->param('Filter') eq 'Done')
	{
		print $form->hidden('Filter');
		my @chosen = ($form->param('selected_authors')); 
		my $auth_regex = $form->param('auth_regex');
		my @temp = $query->select_authors(author_regex => $auth_regex);
		my @auths = $query->select_authors(previous_list => \@chosen);
		print 'Searching in the following: <p>',
			(join '<br>', @auths),
			'<p><hr>';
	}
	$query->do_search;
	close OUT or die ("Can't close output file: $!");
	$form->param('session_num', "$session");
	print $form->hidden('session_num'),
	      $form->hidden('Type');
	$encoding_footer->();
	
};	

##################################################################
#                                                                #
# Page 4 does a TLG brute-force search and prints the results.   #
#                                                                #
##################################################################

my $print_page_4 = sub 
{
	
	$print_title->('Diogenes Greek Search');
	$print_header->();
	print '<p>';
	$form->param('current_page','6');
	print $form->hidden('current_page'),
	      $form->hidden('Type');
	
	my %args;
	$args{output_format} = 'html';
	$args{encoding} = $default_encoding;
	$args{highlight} = 1;
	$args{input_beta} = 1 if ($default_input =~ m/beta/i);
	$args{type} = $Diogenes::choices{$form->param('Type')} || $print_error_page->();
		
	my @pattern = $form->param('query_list');
	@pattern 	= ($form->param('query')) unless @pattern;
	$args{pattern_list} = \@pattern;
	
	if ($form->param('Multiple'))
	{
		$args{min_matches}  = $form->param('Min_Matches');
		$args{context}		= $form->param('Context');
        $args{reject_pattern} = $form->param('Reject') if $form->param('Reject');
	}
	my $aux_file = $TMP;
	chop $aux_file;
	$aux_file = ">$aux_file.bta";
	
	open OUT, $aux_file or die ("Can't open $aux_file: $!");
	binmode OUT;
	$args{aux_out} = \*OUT;
	
	$query = new Diogenes(%args);
    $print_no_database->($query) if not ref $query;
	
	if ($form->param('Filter') and $form->param('Filter') eq 'Done')
	{
		if ($form->param('All_TLG'))
		{
			print $form->hidden('All_TLG');
			my @chosen = $form->param('list_filter'); 
			my @auths = $query->select_authors(author_nums => \@chosen);

			print "\nSearching within the following texts: \n\n<p>";
			print "$auths[$_] <br>\n" for (0 .. $#auths);
			print "\n<p><hr><p>";
		}
		else
		{
			my @params = $form->param;
			my %filter_args;
			print $form->hidden('Filter');
			foreach my $param (@params)
			{
				next unless $param =~ /^Filter_args_(.*)$/;
				$filter_args{$1} = [$form->param($param)];
				print $form->hidden($param);
			}
			# not really an array
			$filter_args{criteria} = @{ $filter_args{criteria} }[0] if 
									exists $filter_args{criteria};
			$filter_args{author_regex} = @{ $filter_args{author_regex} }[0] if
									exists $filter_args{author_regex};
			() = $query->select_authors(%filter_args);
			my @chosen = $form->param('list_filter'); 
			my @auths = $query->select_authors(previous_list => \@chosen);
			print "\nSearching within the following texts: \n\n<p>";
			print "$auths[$_] <br>\n" for (0 .. $#auths);
			print "\n<p><hr><p>";
		}
	}
	
	$query->do_search;
	close OUT or die ("Can't close output file: $!");
	
	$form->param('session_num', "$session");
	print $form->hidden('session_num'),
	      $form->hidden('Type');

	$encoding_footer->();

};

##########################################################
#                                                        #
# Page 5 prints the list of words from the TLG word list #
#                                                        #
##########################################################
my $print_page_5 = sub 
{
	
	$print_title->('Diogenes TLG word list result', 1);
	$print_header->();
	my @params = $form->param;
	
	my %lists;
	my @sets = grep /^list_\d+/, @params;
	if ($form->param('Multiple') and @sets)
	{
		foreach my $list (@sets)
		{
			my $num = $list;
			$num =~ tr/0-9//csd;
			$lists{$num} = [$form->param($list)]; 
		}
		print keys %lists > 1 ? '<p>Here are the sets ' : '<p>Here is the set ';
		print 'of words you previously selected:<p><ol>';
		foreach my $list (reverse sort numerically keys %lists)
		{
			print '<li><p>';
			my %labels;
			foreach my $word (@{ $lists{$list} })
			{
				my $label = $word;
				
				if (not $cgi_latex_word_list)
				{	
					$init->encode_greek($default_encoding, \$label);
				}
				$labels{$word} = $label;
			}
			
			if (not $cgi_latex_word_list)
			{	
				print join ', ', values %labels;
			}
			else 
			{
				my @images;
				foreach my $word (@{ $lists{$list} })
				{
					my $munged_word = $word;
					$munged_word =~ tr#/\\'=!()|#abcdefgh#;
					push @images, $form->img({src=>"$img_dir$munged_word.gif",
						align=>'bottom', alt=>$labels{$word}});
				}
				print join ', ', @images;
			}
			print ".</p></li>\n";
			# Bump list_1 to list_2 and so forth (high to low).
			my $next = $list + 1;
			$form->param(	-name=>"list_$next",
							-values=>$lists{$list} );
			print $form->hidden("list_$next"), "\n";
		}
		print '</ol></p><hr>';
	}
	
	my %args;
	$args{type} = 'tlg';
	$args{input_beta} = 1 if ($default_input =~ m/beta/i);
	$args{output_format} = 'html';
	$args{encoding} = $default_encoding;

	# Add queries
	my $pattern = $form->param('query');
	my @patterns = $form->param('query_list');
	@patterns = () unless @patterns;
	push @patterns, $pattern if $pattern;
	$form->param(-name=>'query_list', -values=>\@patterns);	
	print $form->hidden('query_list'),
		  $form->hidden('Type');
		  
	$query = new Diogenes_indexed(%args);
    $print_no_database->($query) if not ref $query;

	if ($form->param('Filter') and $form->param('Filter') eq 'Done')
	{
		print $form->hidden('Filter'),
			  $form->hidden('list_filter'); 
		if ($form->param('All_TLG'))
		{
			print $form->hidden('All_TLG');
			my @chosen = $form->param('list_filter'); 
			my @auths = $query->select_authors(author_nums => \@chosen);
			print "\nSearching within the following texts: \n\n<p>";
			print "$auths[$_] <br>\n" for (0 .. $#auths);
			print "\n<p><hr><p>";
		}
		else
		{
			my @params = $form->param;
			my %filter_args;
			foreach my $param (@params)
			{
				next unless $param =~ /^Filter_args_(.*)$/;
				$filter_args{$1} = [$form->param($param)];
				print $form->hidden($param);
			}
			# not really an array
			$filter_args{criteria} = @{ $filter_args{criteria} }[0] if 
									exists $filter_args{criteria};
			$filter_args{author_regex} = @{ $filter_args{author_regex} }[0] if
									exists $filter_args{author_regex};
			() = $query->select_authors(%filter_args);
			my @chosen = $form->param('list_filter'); 
			my @auths = $query->select_authors(previous_list => \@chosen);
			print "\nSearching within the following texts: \n\n<p>";
			print "$auths[$_] <br>\n" for (0 .. $#auths);
			print "\n<p><hr><p>";
		}
	}

	my ($wref, @wlist) = $query->read_index($pattern) if $pattern;

	if ($pattern and not @wlist)
	{
		print "<strong>Error: Nothing maches $pattern in the TLG word list!</strong>",
			  '</table>';
		return;
	}

	print '<center>';
	print '<p>Here are the entries in the TLG word list that match your query:</p>'
																if $pattern;
	print '<TABLE border=0><center><TR><TD>';
	
	my (%labels);
	if (not $pattern)
	{
		# do nothing
	}
	elsif (not $cgi_latex_word_list)
	{	# Just print the checkboxes with transliterations
		foreach my $word (@wlist) 
		{
			$labels{$word} = $word;
			$query->encode_greek($default_encoding, \$labels{$word});
			$labels{$word} .= "&nbsp;($wref->{$word}) ";
			$form->autoEscape(undef);
		}
		print $form->checkbox_group(-name=>'list_1', -Values=>\@wlist,
				-labels=>\%labels, 
#				-columns=>'4'
				);
		
		$form->autoEscape(1) ;
	}
	else 
	{	# Here we generate and print little gifs if required.
		my @group = $form->checkbox_group(-name=>'list_1', -Values=>\@wlist,
				-nolabels=>1);

		open TEX, ">$TMP.tex" or die ("$!");
		binmode TEX;
		chdir $tmp_dir or die ("Couldn't chdir to $tmp_dir: $!");
		print TEX $query->simple_latex_boilerplate;

		foreach my $word (@wlist) 
		{
			$labels{$word} = $word;
			Diogenes::beta_encoding_to_ibycus(\$labels{$word});
			print TEX "$labels{$word}\\clearpage\n";
		}

		print TEX "\\end{document}\n";
		close TEX or die ("$!");

		`$latex \`\`\\\\scrollmode\\\\input $TMP.tex\'\'`;
		unlink "$TMP.tex";
		unlink "$TMP.log";
		unlink "$TMP.aux";
		
		my $j = 0;
		foreach my $i (1 .. @wlist) 
		{
			$j++;
			my $word = $wlist[$i - 1];
			$word =~ tr#/\\'=!()|#abcdefgh#;
			unless (-e "$Img_dir$word.gif") 
			{
				my $size = '';
				my ($bbx, $bby, $bbw, $bbh);
				local $/ = "\n";
				system ($dvips, '-q', '-pp', $i, '-E', '-o', "$TMP$word.ps", "$TMP.dvi");
		 		open PS, "$TMP$word.ps" or die ("$!");
				binmode PS;
		 		while (<PS>) 
				{   # Look for bounding box comment
		    	    if (/^\%%BoundingBox:\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/) 
					{
		    	        $bbx = 0 - $1;
						$bby = 0 - $2;
		    	        $bbw = $3 + $bbx; 
						$bbh = $4 + $bby;
		    	        if(($bbw > 0) && ($bbh > 0)) 
						{ 	# a valid bounding box
		    	            print "EPS dimensions are $bbw x $bbh\n" if
															$query->{debug};
			                $size = '-g'.$bbw.'x'.$bbh;
			                last;
						} 
						else 
						{	# e.g. when dvips gives an empty box
					    	warn ("Invalid bounding box"); 
						}
				    }
				}
				warn ("Couldn't find bounding box geometry!") unless $size;
				close PS;
		
				my $outfile = "-sOutputFile=$TMP$word.ppm";
				my $gs_input = "$TMP$word.ps";
				# Without mod_perl the GS> prompt gets printed
				print '<' unless (($ENV{GATEWAY_INTERFACE} 
							and $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/)
							or $Diogenes_Daemon::flag);
			    open (GS, "|$GS $gs_args $size $outfile");
				binmode PS;
		    	print GS "$bbx $bby translate ";
		    	print GS "($gs_input) run ";
			    print GS "showpage " ;
			    print GS "quit\n";
			    close GS;
				system ("$p2g -transparent '#ffffff' $TMP$word.ppm".
								" 1> $Img_dir$word.gif 2> /dev/null");
				unlink "$TMP$word.ps";
				unlink "$TMP$word.ppm";
			}
			
			print $group[$i - 1];
			#print qq{<font size="-1"> ($wref->{$wlist[$i-1]}) </font>};
			print $form->img({src=>"$img_dir$word.gif",
						align=>'bottom', alt=>$labels{$wlist[$i-1]}});
			print qq{<sup> ($wref->{$wlist[$i-1]}) </sup>};
			if ($j > 3) 
			{
				print '</td></tr><tr><td>'; $j = 0;
			}
			else 
			{
				print '</td><td>';
			}
		}
		
		unlink "$TMP.dvi" or die ("$!");
		
	}
	print '</td></tr><tr><td colspan=4 align=center> ',
		  '<p>Select the forms above that interest you.<p>',
		   $form->reset( -value  =>'reset form'),
		   '&nbsp;&nbsp;&nbsp;&nbsp;',
		   $form->button(-value  =>"select all",
						 -onClick=>"setAll()"),
		    '</p>' 										if $pattern;
	print '</td></tr>',
		    '</center></table>',
			'<TABLE border=0><center><TR><TD><center>';
	
		   
	if ($form->param('Multiple'))
	{
		print $form->hidden('Multiple'),
			 '<p>You may add another set of words by entering another ',
			 'pattern below:<p>',
  		  $form->textfield(-name=>'query', -size=>25),
		     '',
#		  '<p><INPUT type=text value="" framewidth=4 name=query size=40></p>',
		  $form->submit(-name=>'Add_Pattern',
						-value=>'Continue'),
		  '';

		my @matches = ('any', 2 .. (keys %lists), 'all');
		print '<hr><h3>Define type of search:</h3>',
		  'Find passages in the TLG the length of ',
		  $form->popup_menu(-name   =>'Context',
							-Values =>\@Diogenes::contexts,
							-Default=>'one sentence'),
		  '<br> in which ',
		  $form->popup_menu(-name   =>'Min_Matches',
							-Values =>\@matches,
							-Default=>'all'),
		  'of these sets of words are represented.',
	      '<hr><h3>Reject pattern:</h3>',
          '<p>Do not display passages matching the following pattern: <p><center>',
  		  $form->textfield(-name=>'Reject', -size=>25, -default=>''),
		  '<hr><p>',
		  $form->submit(	-name	=>'Just_Go',
							-value	=>'Do search'),
		  '</center>';
		$form->param('current_page','1');
	}
	else
	{
		print $form->submit(	-name	 =>'search',
						 		-value  =>'Do Search');
		$form->param('current_page','5');
	}	   
	print '</td></tr>',
		   '</center></table>',
		   $form->hidden('current_page'),
		   $form->hidden('greek_output_format'),
		   $form->hidden('Input_method'),
		   $form->hidden(-name => 'args',
						-default => [%args]),
		   "\n";
	$form->param('session_num', "$session");
	print  $form->hidden('session_num');
	$my_footer->();
};

####################################################
#                                                  #
# page 6 is the output from a tlg word list search #
#                                                  #
####################################################
$handler{process_page_5} = sub 
{
	$print_title->('Diogenes Greek search results');
	$print_header->();
	$form->param('current_page','6');
	print $form->hidden('current_page'),
		  $form->hidden('Type');
	
	my %args = ($form->param('args'));
	$args{context} = $form->param('Context');
	$args{context} ||= 'one sentence';
	$args{output_format} = 'html';
	$args{encoding} = $default_encoding;
	$args{highlight} = 1;
	
	my $aux_file = $TMP;
	chop $aux_file;
	$aux_file = ">$aux_file.bta";
	
	open OUT, $aux_file or die ("Can't open $aux_file: $!");
	binmode OUT;
	$args{aux_out} = \*OUT;
	
	if ($form->param('Multiple'))
	{
		$args{min_matches}  = $form->param('Min_Matches');
		$args{context}		= $form->param('Context');
        $args{reject_pattern} = $form->param('Reject') if $form->param('Reject');
	}
	
	$query = new Diogenes_indexed(%args);
    $print_no_database->($query) if not ref $query;
	
	if ($form->param('Filter') and $form->param('Filter') eq 'Done')
	{
		print $form->hidden('Filter');
		if ($form->param('All_TLG'))
		{
			print $form->hidden('All_TLG');
			my @chosen = $form->param('list_filter'); 
			my @auths = $query->select_authors(author_nums => \@chosen);
			print "\nSearching within the following texts: \n\n<p>";
			print "$auths[$_] <br>\n" for (0 .. $#auths);
			print "\n<p><hr><p>";
		}
		else
		{
			my @params = $form->param;
			my %filter_args;
			foreach my $param (@params)
			{
				next unless $param =~ /^Filter_args_(.*)$/;
				$filter_args{$1} = [$form->param($param)];
				print $form->hidden($param);
			}
			# not really an array
			$filter_args{criteria} = @{ $filter_args{criteria} }[0] if 
									exists $filter_args{criteria};
			$filter_args{author_regex} = @{ $filter_args{author_regex} }[0] if
									exists $filter_args{author_regex};
			() = $query->select_authors(%filter_args);
			my @chosen = $form->param('list_filter'); 
			my @auths = $query->select_authors(previous_list => \@chosen);
			print "\nSearching within the following texts: \n\n<p>";
			print "$auths[$_] <br>\n" for (0 .. $#auths);
			print "\n<p><hr><p>";
		}
	}

	my @patterns = $form->param('query_list');
	my $pattern = $form->param('query');
	@patterns = ($pattern) unless @patterns;
#	@patterns = () unless @patterns;
#	push @patterns, $pattern if $pattern; 
	

	my @params = $form->param;
	my @selected;
	foreach my $list (grep /^list_\d/, @params)
	{
		my $num = $list;
		$num =~ tr/0-9//csd;
		push @selected, [$form->param($list)]; 
	}
	
	$query->read_index($_) for @patterns;
	$query->do_search(@selected);
	close OUT or die ("Can't close output file: $!");
	
	$form->param('session_num', "$session");
	print  $form->hidden('session_num');
	       $encoding_footer->();
};

my $print_latex_page = sub 
{
	$print_title->('Diogenes Latex Page');
	$print_header->();
	
	my $old_session = $form->param('session_num');
	my %args;
	$args{output_format} = 'latex';
	open BETA, "<$tmp_prefix$old_session.bta" or die $!;
	binmode BETA;
	$args{input_source} = \*BETA;
	$args{type} = 'none';
	$args{printer} = 1 if $form->param('greek_output_format') =~ m/postscript/i;
	$query = new Diogenes(%args);

	my $page  = $form->param('Page')  || 1;
	my $pages = $form->param('Pages') || 0;

	if ($form->param('Forward')) {
		$page += 1;
	}
	elsif ($form->param('Back')) {
		$page -= 1;
	}
	elsif ($form->param('Jump')) {
		$page = $form->param('page_menu');
	}

    # We have to rerun latex if we have lost track of the number of
    # pages in the .dvi file, an this is actually desirable, such as
    # when we want to switch from the display to the printer version
    # or vice versa.
	unless ((-e  "$tmp_prefix$old_session.dvi") and $pages)
	{	
		open TEX, ">$tmp_prefix$old_session.tex" or die $!;
		binmode TEX;
		my $old_fh = select TEX;
		$query->do_format;
		select $old_fh;
		
		# Run latex if there is no .dvi file
		chdir $tmp_dir or die ("Couldn't chdir to $tmp_dir: $!");
		
		my $tex_out = `$latex \`\`\\\\scrollmode\\\\input $tmp_prefix$old_session.tex\'\'`;
		$tex_out =~ m#Output written[^\(]+\((\d+)\s+page#s or 
											die ("Couldn't get total pages!");
		$pages = $1;
		unlink "$tmp_prefix$old_session.tex";
		unlink "$tmp_prefix$old_session.log";
		unlink "$tmp_prefix$old_session.aux";
	} 
	
	if ($form->param('greek_output_format') =~ m/latex_postscript/i) 
	{	# PostScript for printers 
		system ($dvips, '-q', '-Pcmz', '-o', "$Img_dir$session.ps", "$tmp_prefix$old_session.dvi");
		die ("No ps file!") unless -e "$Img_dir$session.ps";
		
		print '<center><blockquote>Below is a link to the PostScript file. <p>
		You can save this file onto your computer, and then print it by dragging and dropping
		the file onto the icon of a PostScript printer.</blockquote><p>';
		print "<a href=\"$img_dir$session.ps\"> Click here to
		download.</a> </center>";
		return;
	}
    
	# Only run dvips, gs, and ppmtogif if the gif has not been cached
	unless (-e "$Img_dir"."$old_session.$page.gif")
	{	
		my $junk = `$dvips -Pcmz -pp $page -E -o $TMP.ps $tmp_prefix$old_session.dvi 2>&1`;
		
		open PS, "$TMP.ps" or die ("$!");
		binmode PS;
		local $/ = "\n";
		my $size = '';
		my ($bbx, $bby, $bbw, $bbh);
		while (<PS>) 
		{
	  	    # Look for bounding box comment
	 	    if (/^%%BoundingBox:\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/) 
			{
		        $bbx = 0 - $1;    
				$bby = 0 - $2;
	   	        $bbw = $3 + $bbx; 
				$bbh = $4 + $bby;
				$bbw += 10;  # add a 5pt margin for safety
	   	        if(($bbw > 0) && ($bbh > 0)) 
				{ # we have a valid bounding box
		            print "EPS dimensions are $bbw x $bbh\n" if
														$query->{debug};
		            $size = '-g'.$bbw.'x'.$bbh;
		            last;
				} 
				else 
				{  # i.e. when dvips gives an empty box
			    	warn ("Invalid bounding box"); 
				}
		    }
		}
		warn ("Couldn't find bounding box geometry!") unless $size;
		close PS;
			
		my $outfile = "-sOutputFile=$TMP.ppm";
		my $gs_input = "$TMP.ps";
		# Without mod_perl the GS> prompt gets printed
		print '<' unless (($ENV{GATEWAY_INTERFACE} 
					and $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/)
					or $Diogenes_Daemon::flag);
	    open (GS, "|$GS $gs_args $size $outfile");
		binmode GS;
	   	print GS "$bbx $bby translate ";
	   	print GS "($gs_input) run ";
	    print GS "showpage " ;
	    print GS "quit\n";
	    close GS;
		system ("$p2g -transparent '#ffffff' $TMP.ppm".
				" 1> $Img_dir"."$old_session.$page.gif 2> /dev/null");
		unlink "$TMP.ps";
		unlink "$TMP.ppm";
	}
	$form->param('Page', $page);
	$form->param('Pages', $pages);
	print  $form->hidden('Page'),
		   $form->hidden('Pages'),
		   $form->hidden('current_page'),
		   $form->hidden('session_num'),
		   '<CENTER>',
		   $form->img({src=>"$img_dir"."$old_session.$page.gif",
					   alt=>'Search Result'}),
		   '</CENTER>',

		   '<p><center><TABLE border=0><TR><TD><CENTER>',
		   "<p><hr><p><center>This is page $page of $pages.</center><p>";

	if ($page > 1) {
		print $form->submit(-name=>'Back',
						-value=>'Move Back');
	}
	if ($page < $pages) {	
		print $form->submit(-name=>'Forward',
						-value=>'Move Forward');
	}
	unless ($pages == 1) {
		print $form->p,
			 'Jump to page: ',
			 $form->popup_menu( -name   =>'page_menu',
								-Values =>[1 .. $pages],
								-Default=>$page),
			 $form->submit( -name  =>'Jump',
							-value =>'Go');
	}
	
	print '</TD></TR></CENTER></TABLE>';
	print  $form->hidden('greek_output_format');
	$my_footer->();
	
};

######################################################
#                                                    #
# subsequent page 6's are reformatting of old output #
#                                                    #
######################################################

$handler{process_page_6} = sub 
{
	if ($form->param('greek_output_format') =~ m/latex|postscript/i)
	{
		$print_latex_page->();
	}
    elsif (grep m/^GetContext/, $form->param())
    {   # Check to see if we are switching to the browser
        $handler{process_page_13}->();
    }
		
    
	else
	{
		$print_title->('Diogenes Reformatted Greek Page');
		$print_header->();
		my $old_session = $form->param('session_num');
		my %args;
		$args{output_format} = 'html';
		$args{perseus_links} = 1 if $form->param('add_perseus_links');
		my $enc = $form->param('greek_output_format') || $default_encoding;
		if ($enc =~ m/^\s*latin/i)
		{
			$args{encoding} = 'Ibycus' ;
		}
		elsif ($enc =~ m/^\s*beta/i)
		{
			$args{encoding} = 'Beta';
		}
		else 
		{
			$args{encoding} = $enc;
		}
		open BETA, "<$tmp_prefix$old_session.bta" or 
				die "Could not open $tmp_prefix$old_session.bta:  $!\n";
		binmode BETA;
		$args{type} = 'none';
		$args{input_source} = \*BETA;
		$query = new Diogenes(%args);
		$query->do_format;
		    
			
		print $form->hidden('session_num'),
              $form->hidden('add_perseus_links'),
	          $form->hidden('Type'),
			  $form->hidden('current_page');
		
		$encoding_footer->();
		
	}
};

###############################################################
#                                                             #
# Form to restrict scope of TLG searches by genre, date, etc. #
# And other databases by author/file.                         #
#                                                             #
###############################################################

my $print_page_7 = sub 
{
	$print_title->('Diogenes Text Filter', 'filter');
	$print_header->();
	print  $form->hidden('query'),
		   $form->hidden('query_list'),
		   $form->hidden('Type'),
		   $form->hidden('Multiple'),
		   $form->hidden('Context'),
		   $form->hidden('Min_Matches'),
		   $form->hidden('Reject'),
		   $form->hidden('Input_method'),
		   $form->hidden('greek_output_format');
	my %args;

	if ($Diogenes::choices{$form->param('Type')}) 
	{
		$args{type} = $Diogenes::choices{$form->param('Type')};
	}
	else
	{
		$print_error_page->();
	}
	$args{output_format} = 'html';
	$args{encoding} = $default_encoding;
	
	$query = new Diogenes(%args);
    $print_no_database->($query) if not ref $query;
		
	print '<center>';
	
	if ($args{type} ne 'tlg')
	{	# No info files, so we allow a selection from all works
		my $auth_regex = $form->param('auth_regex');
		if (not $auth_regex)
		{
			print $form->hidden('current_page');
			$form->param('Filter', 'regex');
			print $form->hidden('Filter');
			print "Please type a pattern matching part of the name(s) of the ",
				"author(s) you wish to specify<p>",
					'<CENTER><TABLE border=0><TR><TD>',
				$form->textfield(-name=>'auth_regex', -size=>25),
				  '<p></td></tr><tr><td><center>',
				  $form->submit(-name  =>'submit',
								-value =>'Continue');
		}
		else
		{
			# Go back after this to process search
			$form->param('Filter', 'Done');
			print $form->hidden('Filter');
			$form->param('current_page', '1');
			print $form->hidden('current_page');
			print $form->hidden('auth_regex');
		
			my @auths = $query->select_authors(-author_regex => $auth_regex);
			my $nn;
			my %labels = map {$nn++ => $_} @auths;
		    $form->autoEscape(undef);
	
		    print 	'Here is a list of matching authors or corpora ',
					'from the database you specified.<p>',
	    			'Please select as many as you wish to search in<br>',
					' and click on the button at the bottom. <p>',
					'<TABLE border=0><TR><TD>',
					
				  $form->checkbox_group(-name=>'selected_authors',
						-Values=>[0..$#auths],
						-linebreak=>'true',
						-labels=>\%labels,
						),
				  $form->p,
				  '</td></tr><tr><td><center>',
				  $form->reset(-value=>'Reset form'),
				  '<p></td></tr><tr><td><center>',
				  $form->submit(-name  =>'submit',
								-value =>'Continue');
		}
	}
	else
	{
		my %labels = %{ $query->select_authors(get_tlg_categories => 1) };
		$form->param('Filter', 'Done');
		print  $form->hidden('Filter');
		$form->param('current_page', '7');
		print $form->hidden('current_page'),
	     	'Here are the various criteria by which the texts<br> contained ',
			'in the TLG are classified.<p>',
		 	'<TABLE border=0><TR><TD>',
			'</td></tr><tr><td>';
			
		my %nice_labels = 	(	'epithet'   => 'Author\'s genre',
								'genre_clx' => 'Text genre',
								'location'  => 'Location'
							);
		my $j = 0;
		foreach my $label (sort keys %labels)
		{
			next if $label eq 'date' or $label eq 'gender' or $label eq 'genre';
			$j++;
			print "<strong>$j. $nice_labels{$label}:</strong><br>";
			print $form->scrolling_list(-name=>$label,
						-Values=>\@{ $labels{$label} },
						-multiple=>'true',
						-size=>8);
			print '</td><td>';
		}
		print '</td></tr><tr><td>';
		$j++;
		print "<strong>$j. Gender:</strong><br>",
			  $form->scrolling_list(-name     =>'gender',
									-Values   =>\@{ $labels{gender} },
									-multiple =>'true'),
			  '</td><td colspan=2>';
		$j++;
		print "<strong>$j. Name of Author(s):</strong><br>",
  		  	  $form->textfield(-name=>'auth_regex', -size=>25),
#			  '<INPUT type=text value="" name=auth_regex size=40><p>',
		
			  '<p></td></tr></table>',
			  '<TABLE border=0><TR><TD colspan=2>';
		$j++;
		print "<strong>$j. Date Range:</strong>",
			  '</td></tr><tr><td>',
			  "After &nbsp;",
			  '</td><td>';
		my @dates = @{ $labels{date} };
		pop @dates while $dates[-1] =~ m/Varia|Incertum/;
		unshift @dates, '--';
		print $form->popup_menu(-name=>'date_after',
								-Values=>\@dates,
								-Default=>'--'),
			 '</td><td rowspan=2>',
			 $form->checkbox(-name =>'Varia',
			 				 -label=>' Include Varia and Incerta?'),
		
			 '</td></tr><tr><td>',
			 "Before ",
			 '</td><td>',
			 $form->popup_menu(-name=>'date_before',
					-Values=>\@dates,
					-Default=>'--'),
		
			 '</td></tr></table><p>',
    		 	'You may select multiple values for as many ',
				'of the above criteria as you wish.<p>',
				'Then indicate below how many of ',
				'the stipulated criteria a text must meet <br>',
				'in order to be included in the search. <p>',
			 '<TABLE border=0><TR><TD>',
			 "<p><strong>Number of criteria to match: </strong>";
		my @crits = ('Any', 2 .. --$j, 'All');
		print $form->popup_menu(-name=>'criteria',
								-Values=>\@crits,
								-Default=>$default_criteria),
			 '</td><td>',
			 $form->submit(	-name=>'Get_Texts',
							-value=>'Get Matching Texts'),
			 '</td></tr><tr><td colspan=2><center><hr><p>',
				'You also have the option to select from a list of all<br>',
				'the texts in the corpus<p>',
			 $form->submit(-name=>'Get_All',
						-value=>'Browse All Texts');
	}
		
	print '</TD></TR></TABLE>',
		  '</center>';
	$my_footer->();
	
};

###########################################################
#                                                         #
# Here we print out the works selected from the TLG canon #
#                                                         #
###########################################################

$handler{process_page_7} = sub 
{
	$print_title->('Diogenes Text Filter', 'filter');
	$print_header->();
	# Go back after this to process search
	$form->param('current_page', '1');
	$form->param('Filter', 'Done');
	print  $form->hidden('current_page'),
		   $form->hidden('Filter'),
		   $form->hidden('query'),
		   $form->hidden('query_list'),
		   $form->hidden('Type'),
		   $form->hidden('Multiple'),
		   $form->hidden('Context'),
		   $form->hidden('Min_Matches'),
		   $form->hidden('Reject'),
		   $form->hidden('Input_method'),
		   $form->hidden('greek_output_format');
	
	my %args;
	if ($Diogenes::choices{$form->param('Type')} eq 'tlg') 
	{
		$args{type} = 'tlg';
	}
	else
	{
		$print_error_page->();
	}
	$args{output_format} = 'html';
	$args{encoding} = $default_encoding;
	$query = new Diogenes(%args);
    $print_no_database->($query) if not ref $query;
	undef %args;
	
	$args{epithet}   = [$form->param('epithet')]   if $form->param('epithet');
	$args{genre_clx} = [$form->param('genre_clx')] if $form->param('genre_clx');
	$args{location}  = [$form->param('location')]  if $form->param('location');
	$args{gender}    = [$form->param('gender')]    if $form->param('gender');
	$args{author_regex} = $form->param('auth_regex') if $form->param('auth_regex');
	$args{criteria} = $form->param('criteria') if $form->param('criteria');
	$args{criteria} = 1 if $args{criteria} =~ m/any/;
#	$args{criteria} = 6 if $args{criteria} eq 'All';
	my @dates;
	push @dates, $form->param('date_after') ;
	push @dates, $form->param('date_before') ;
	push @dates, 1, 1 if $form->param('Varia');

	@{ $args{date} } = @dates if @dates and (($form->param('date_after') ne '--') and ($form->param('date_before') ne '--'));
	
	print '<center>';
	
	if ($form->param('Get_All'))
	{
		$args{select_all} = 1;
		my %auths = %{ $query->select_authors(%args) };
		$form->autoEscape(undef);
        my $formatted_auth;
        foreach my $auth_num (keys %auths)
        {
            $formatted_auth = $auths{$auth_num};
            #print ">$bare_auth, ";
            $query->format_output(\$formatted_auth, 'l');
            $auths{$auth_num} = $formatted_auth;
            #print ">$bare_auth, ";
        }

	    print 	'Here is a list of all the texts contained ',
				'in the TLG.<p>',
    	 	 	'Please select as many as you wish to search in<br>',
				' and click on the button at the bottom. <p>',
			    '<TABLE border=0><TR><TD>';
		
		#print $form->scrolling_list(-name=>'list',
		#							-Values=>[sort numerically keys %auths],
		#							-labels=>\%auths,
		#							-multiple=>'true');
		print $form->checkbox_group(-name=>'list_filter',
									-Values=>[sort numerically keys %auths],
									-labels=>\%auths,
									-columns=>'2'
									);
		print  $form->p,
			   '</td></tr><tr><td><center>',
			   $form->reset( -value=>'Reset form'),
			   '&nbsp;&nbsp;&nbsp;&nbsp;',
			   $form->button(-VALUE  =>"Select All",
							 -onClick=>"setAll()"),
			   '<p>',
			   '</td></tr><tr><td><center>',
			   $form->submit(-name =>'All_TLG',
							 -value=>'Continue'),
			   '</td></tr></table></center>';
		$my_footer->();
		return;
	}
	
	$form->autoEscape(undef);
	my @texts = $query->select_authors(%args);
    print 	'Here is a list of the texts that matched ',
			'your query.<p>',
   	 	 	'Please select as many as you wish to search in<br>',
			' and click on the button at the bottom. <p>',
		    '<TABLE border=0><TR><TD>';
	
	my %labels;
	$labels{$_} = $texts[$_] for (0 .. $#texts);
	
	#print $form->scrolling_list(-name=>'list',
	#							-Values =>[0 .. $#texts],
	#							-labels =>\%labels,
	#							-multiple=>'true');
	print $form->checkbox_group(-name=>'list_filter',
								-Values=>[0 .. $#texts],
								-labels=>\%labels,
								-linebreak=>'true'
								);
	print  '</td></tr><tr><td>',
		   '<center><p>',
		   $form->reset( -value=>'Reset form'),
		   '&nbsp;&nbsp;&nbsp;&nbsp;',
		   $form->button(-VALUE=>"Select All",
						 -onClick=>"setAll()"),
		   '<p>',
		   $form->submit(-name=>'Filtered_TLG',
						 -value=>'Continue'),
		   '</center>',
		   '</td></tr></table></center>';

	foreach my $arg (keys %args) 
	{
		if (ref($args{$arg}) eq 'ARRAY')
		{ 
			print "\n";
			print $form->hidden(-name=>"Filter_args_$arg", 
								-default=>\@{ $args{$arg} });
		}
		else 
		{ 
			print $form->hidden("Filter_args_$arg", $args{$arg});
		}
	}
	
	$my_footer->();

};

############################################
#                                          #
# page 10 is the first page of the browser #
#                                          #
############################################
my $print_page_10 = sub 
{
	$print_title->('Diogenes Author Browser');
	$print_header->();
	print '<center>';
	print $form->p;

	my %args;
	$form->param('current_page','11');
    $args{type} = $Diogenes::choices{$form->param('Type')};
	print $form->hidden('current_page'),
		  $form->hidden('Type');

	$args{output_format} = 'html';
	$args{encoding} = 'UTF-8';

	$query = new Diogenes_browser_stateless(%args);
    $print_no_database->($query) if not ref $query;
	my %auths = $query->browse_authors($form->param('query'));
    $strip_html->(\$_) for values %auths;
    
	if (keys %auths == 0) 
	{
		print '<strong>Sorry, no matching names</strong><p>',
		 'To browse texts, enter part of the name of the author ',
		 'or corpus you wish to examine.<p>  Remember to specify the ',
		 'correct database and note that capitalization ',
		 'of names is significant.<p>'
	}
	elsif (keys %auths == 1) 
	{
        my $auth = (keys %auths)[0];
		
		print  $form->hidden('author', $auth),
			   '<TABLE border=0><TR><TD><CENTER>',
	    	   'There is only one author corresponding to your request:<p>',
			   "$auths{$auth} <p>",
        	   $form->submit(-name=>'author',
							 -value=>'Show works by this author'),
			   '</TD></TR></CENTER></TABLE>';
    }
    else 
	{
        my $size = keys %auths;
        $size = 20 if $size > 20;
		print  '<TABLE border=0><TR><TD><CENTER>',
	    	   'Here is a list of authors corresponding to your request.<p>',
    		   'Please select one and click on the button below. <p>',
			   $form->scrolling_list(-name=>'list',
               				 -Values=>[sort {author_sort($auths{$a}, $auths{$b})} keys %auths],
               #							 -Values=>[sort author_sort keys %auths],
							 -labels=>\%auths, -size=>$size),
			   $form->p,
			   $form->submit(-name=>'submit',
							 -value=>'Show works by this author'),
			   '</TD></TR></CENTER></TABLE>';
    }
	
	print '</center>';
	$my_footer->();
    
    sub author_sort
    {
        my ($a, $b) = @_; 
        $a =~ tr/a-zA-Z//cd;
        $b =~ tr/a-zA-Z//cd;
	    return (uc $a cmp uc $b);
    }
};



#################################
#                               #
# page 12 shows a list of works #
#                               #
#################################
$handler{process_page_11} = sub 
{
	my $auth;
	$print_title->('Diogenes Work Browser');
	$print_header->();

	$form->param('current_page','12');
	print $form->hidden('current_page'),
		  $form->hidden('Type'),
		  '<center>',
		  $form->p;
	
	my %args;
    $args{type} = $Diogenes::choices{$form->param('Type')};
	$args{output_format} = 'html';
	$args{encoding} = 'UTF-8';
	
	
	if ($form->param('submit'))  
	{
		$auth = $form->param('list');
	}	
	else 
	{
		$auth = $form->param('author');
	}

	$query = new Diogenes_browser_stateless(%args);
    $print_no_database->($query) if not ref $query;
	my %works = $query->browse_works ($auth);
    # Because they are going into form elements, and most browsers
    # do not allow HTML there.
    $strip_html->(\$_) for (values %works, keys %works);
       
	if (keys %works == 0) 
	{
		print '<strong>Sorry, no matching names</strong><p>'
	}
	elsif (keys %works == 1) 
	{
        my $work = (keys %works)[0];
		
		print $form->hidden('work', $work),
			  '<TABLE border=0><TR><TD><CENTER>',
	    	  'There is only one work by this author:<p>',
			  "$works{$work} <p>",
			  $form->submit(-name=>'work',
							-value=>'Find a passage in this work'),
			  '</TD></TR></CENTER></TABLE>';

    }
    else 
	{
		print  '<TABLE border=0><TR><TD><CENTER>',
	    	   'Here is a list of works by your author.<p>',
    		   'Please select one. <p>',
			   $form->scrolling_list(-name=>'works',
									-Values=>[sort numerically keys %works],
									-labels=>\%works),
			   $form->p,
			   $form->submit(-name=>'submit',
						-value=>'Find a passage in this work'),
			   '</TD></TR></CENTER></TABLE>';
    }
	$form->param('author', $auth);
	print  $form->hidden('author'),
		   '</center>';
	$my_footer->();
};

##########################################
#                                        #
# page 13 allows a selection of location #
#                                        #
##########################################
$handler{process_page_12} = sub 
{
	my ($j, $auth, $work, $lab, $lev);
	$print_title->('Diogenes Passage Browser');
	$print_header->();

	my %args;
    $args{type} = $Diogenes::choices{$form->param('Type')};
	$args{output_format} = 'html';
	$args{encoding} = 'UTF-8';
	$form->param('current_page','13');
	print $form->hidden('Type'),
		  $form->hidden('current_page'),
		  '<center>',
		  $form->p;
	
	if ($form->param('submit'))  
	{
		$work = $form->param('works');
	}	
	else 
	{
		$work = $form->param('work');
	}
	
	$auth = $form->param('author');
	$form->param('work', $work);
	print $form->hidden('author'),
		  $form->hidden('work'),
		  $form->hidden('New', 'true'),
	
    	  'Please select the passage you require by filling ',
   		  'out the following form with the appropriate numbers; ',
		  '<br>then click on the button below.<p>',
		  '(Hint: use zeroes to see the very beginning of ',
		  'a work, <br>including the title and proemial material.)<p>';
        
	$query = new Diogenes_browser_stateless(%args);
    $print_no_database->($query) if not ref $query;
	my @labels = $query->browse_location ($auth, $work);
	
	$j = $#labels;
	print $form->hidden('levels', $j); # base 0, that is.
	print '<TABLE border=0><TR><TD>';
	foreach $lev (@labels) 
	{
		$lab = $lev;
		next if $lab =~ m#^\*#; 
		$lab =~ s#^(.)#\U$1\E#;
		print  "$lab: ", '</td><td>', 
  		  $form->textfield(-default=>'0', -name=>"level_$j", -size=>25),
#			'<INPUT type=text value="0" framewidth=4 name=', "level_$j", 
#			' size=40>',
			'</td></tr><p><tr><td>';
				
		$j--;
	}
	print '</td></tr><tr><td colspan=2><center>',
		   $form->p,
		   $form->submit(-name=>'submit',
						-value=>'Show me this passage'),
		   '</center></TABLE>',
		   '</center>';
	$my_footer->();

};

#####################################
#                                   #
# page 13 shows the desired passage #
#                                   #
#####################################
$handler{process_page_13} = sub 
{
	my ($auth, $work, $levels, @target, $abs_begin, $abs_end);
	my ($junk);
	
	$print_title->('Diogenes Browser');
	$print_header->();
	
	my %args;
    $args{type} = $Diogenes::choices{$form->param('Type')};
	my $out_form = $form->param('greek_output_format');
	$out_form ||= $default_encoding;
	
    my $perseus_links = 1 if $init->{perseus_links} or $form->param('add_perseus_links');
    $args{perseus_links} = $perseus_links;
	
	if 	($args{type} eq 'tlg' or $args{type} eq 'ddp' or 
		 $args{type} eq 'ins' or $args{type} eq 'chr') 
	{	# Greek
		$args{output_format} = 'html';
		$args{encoding}		 = $out_form;
		$args{input_lang} = 'g';
		if ($out_form =~ m/latex/i)
		{
			$args{output_format} = 'html';
			$args{encoding}		 = $default_encoding;
			$form->param('greek_output_format', $default_encoding);
		}
	}
	else 
	{	# Latin
		$args{output_format} = 'html';
	}
	
	my $aux_file = $TMP;
	chop $aux_file;
	$aux_file = ">$aux_file.bta";
	
	open OUT, $aux_file or die ("Can't open $aux_file: $!");
	binmode OUT;
	$args{aux_out} = \*OUT;

	$query = new Diogenes_browser_stateless(%args);
    $print_no_database->($query) if not ref $query;
	$auth = $form->param('author');
	$work = $form->param('work');
	$levels = $form->param('levels');
	$form->param('current_page','13');
    if (defined $levels)
    {
	    for (my $j = $levels; $j >= 0; $j--) 
	    {
	    	push @target, $form->param("level_$j");
	    }
    }
	print '<blockquote>';
	
	$abs_begin = $form->param('begin_offset');
	$abs_end =  $form->param('end_offset');
	
	if ($form->param('New')) 
	{ 
		($abs_begin, $abs_end) = $query->seek_passage ($auth, $work, @target);
        $query->begin_boilerplate;
		($abs_begin, $abs_end) = $query->browse_forward 
										 ($abs_begin, $abs_end, $auth, $work);
        $query->end_boilerplate;
		$form->param('session_num', "$session");
	}	
	elsif ($form->param('Forward')) 
	{
        $query->begin_boilerplate;
		($abs_begin, $abs_end) = $query->browse_forward 
										 ($abs_begin, $abs_end, $auth, $work);
        $query->end_boilerplate;
		$form->param('session_num', "$session");
	}
	elsif ($form->param('Back')) 
	{
        $query->begin_boilerplate;
		($abs_begin, $abs_end) = $query->browse_backward 
										 ($abs_begin, $abs_end, $auth, $work);
        $query->end_boilerplate;
		$form->param('session_num', "$session");
	}
    # Set up the browser if we have come from a search result
	elsif (my @ary = grep m/^GetContext/, $form->param()) 
	{
        my $param = pop @ary;
        $param =~ s#^GetContext~~~##;
		($auth, $work, $abs_begin) = split /~~~/, $param;
        $abs_end = -1;
        $query->begin_boilerplate;
		($abs_begin, $abs_end) = $query->browse_forward 
										 ($abs_begin, $abs_end, $auth, $work);
        $query->end_boilerplate;
		$form->param('session_num', "$session");
		$form->param('author', "$auth");
		$form->param('work', "$work");
	}
	else 
	{
		my $old_session = $form->param('session_num');
		open BETA, "<$tmp_prefix$old_session.bta" or die $!;
		binmode BETA;

		if ($out_form !~ m/latex|postscript/i) 
		{
			my $formatter = new Diogenes(	'type' => 'none',
                                            'input_source' => \*BETA,
											'output_format' => 'html',
											'perseus_links' => $perseus_links,
											'encoding' => $out_form);
			$formatter->do_format;
			
		}
		else	# LaTeX output
		{
			open TEX, ">$TMP.tex" or die $!;
			binmode TEX;
			my $old_fh = select TEX;
	        my $printer = 0;
            $printer = 1 if $out_form =~ m/postscript/i;
			my $formatter = new Diogenes(	'type' => 'none',
                                            'input_source' => \*BETA,
											'output_format' => 'latex',
                                            'printer' => $printer,
											'encoding' => 'Ibycus');
			$formatter->do_format;
			select $old_fh;
			close TEX or die $!;
		
			chdir $tmp_dir or die ("Couldn't chdir to $tmp_dir: $!");
			$junk = `$latex \`\`\\\\scrollmode\\\\input $TMP.tex\'\'`;
			unlink "$TMP.tex" or die ("$!");
			
			system ($dvips, '-q', '-pp 1', '-E', '-o', "$TMP.ps", "$TMP.dvi"); 
			unlink "$TMP.dvi" or die ("$!");
            
            if ($out_form =~ m/^\s*latex_postscript/i)
            {
		        die ("No ps file!") unless -e "$TMP.ps";
                rename "$TMP.ps", "$Img_dir$session.ps";
		
        		print '<center><blockquote>Below is a link to the PostScript file. <p>
        		You can save this file onto your computer, and then print it by dragging and dropping
         		the file onto the icon of a PostScript printer.</blockquote><p>';
        		print "<a href=\"$img_dir$session.ps\"> Click here to
        		download.</a> </center>";
         		return;
            }
                
				
			open PS, "$TMP.ps" or die ("$!");
			binmode PS;
			local $/ = "\n";
			my ($bbx, $bby, $bbw, $bbh);
			my $size = '';
			while (<PS>) 
			{ 	# Look for bounding box comment
		   	    if (/^%%BoundingBox:\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/) 
				{
		   	        $bbx = 0 - $1;    
					$bby = 0 - $2;
		   	        $bbw = $3 + $bbx; 
					$bbw += 10;  	# add a 5pt margin for safety
					$bbh = $4 + $bby;
		   	        if (($bbw > 0) && ($bbh > 0)) 
					{ # we have a valid bounding box
			            print "EPS dimensions are ${bbw}x$bbh\n" if
															$query->{debug};
			            $size = "-g$bbw" . 'x' . "$bbh ";
			            last;
					} 
					else 
					{   # i.e. when dvips gives an empty box
				    	warn ("Invalid bounding box"); 
					}
			    }
			}
			warn ("Couldn't find bounding box geometry!") unless $size;
			close(PS);
			
			my $outfile = "-sOutputFile=$TMP.ppm";
			my $gs_input = "$TMP.ps";
			# Without mod_perl the GS> prompt gets printed
			print '<' unless (($ENV{GATEWAY_INTERFACE} 
						and $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/)
						or $Diogenes_Daemon::flag);
		    open (GS, "|$GS $gs_args $size $outfile");
			binmode GS;
	    	print GS "$bbx $bby translate ";
	    	print GS "($gs_input) run ";
		    print GS "showpage " ;
		    print GS "quit\n";
		    close GS;
			system ("$p2g -transparent '#ffffff' $TMP.ppm ".
					"1> $Img_dir$session"."browse.gif 2> /dev/null");
			unlink "$TMP.ps";
			unlink "$TMP.ppm";
			print '<CENTER>',
				  $form->img({src=>"$img_dir$session"."browse.gif",
							alt=>'Browser Result'}),
				  '</CENTER>';
		}
		close BETA or die $!;
	}
	$form->param('begin_offset', $abs_begin);
	$form->param('end_offset', $abs_end);

    print  $form->hidden('current_page'),
		   $form->hidden('Type'),
		   $form->hidden('author'),
		   $form->hidden('work'),
		   $form->hidden('levels');

	print '</blockquote>',
		   $form->hidden('begin_offset'),
		   $form->hidden('end_offset'),
		   '<p><center><TABLE border=0><TR><TD><CENTER>',
		   $form->submit(-name =>'Back',
						 -value=>'Move Back'),
		   $form->submit(-name =>'Forward',
						 -value=>'Move Forward'),
		   '</TD></TR></CENTER></TABLE></center>';
	
	print  $form->hidden('session_num');
	
	$encoding_footer->();

};

sub numerically { $a <=> $b; }

#########################################################################
#                                                                       #
# Delete /tmp/diogenes* files and gifs in $Img_dir if they haven't been #
# accessed in a day                                                     #
#                                                                       #
#########################################################################
my $clean_garbage = sub 
{
	my (@tmp_files, $file);

	opendir TMPDIR, $tmp_dir or die ("Can't open tmp dir! $!");
	@tmp_files = grep /^$prefix/, readdir TMPDIR;
	foreach $file (@tmp_files) 
	{
		unlink "$tmp_dir$file" if -A "$tmp_dir$file" > 1;
	}
	closedir TMPDIR;
	
	opendir IMGDIR, $Img_dir or die ("Can't open Img dir! $!");
	@tmp_files = grep !/^Diogenes_/, readdir IMGDIR;
	foreach $file (@tmp_files) 
	{
		unlink "$Img_dir$file" if -A "$Img_dir$file" > 1;
	}
	closedir TMPDIR;
};

###################################################################
#                                                                 #
# Page 1 is the opening page, with choice of general search type  #
#                                                                 #
###################################################################
$handler{process_page_1} = sub 
{
	unless ($form->param('query') 
		 or $form->param('query_list')
		 or $form->param('Browse') 
		 or ($form->param('Multiple') 
		    and $form->param('Type') =~ m/TLG Word List/i) )
	{
		print '<center><strong>Error.</strong><p>You must specify a
		search pattern.</center>';
		return;
	}
	
	if ($form->param('Multiple') and $form->param('Type') !~m/TLG Word List/i)
	{
		unless ($form->param('Just_Go') or
		$form->param('Filter') and 
		($form->param('Filter') eq 'Done' or $form->param('Filter') eq 'regex')) 
		{
			$print_page_2->();
			return;
		}
	}
	
	if ($form->param('Browse')) 
	{
		$print_page_10->();
	}
	elsif ($form->param('Filter') and $form->param('Filter') ne 'Done')
	{
		$print_page_7->();
	}
	elsif ($form->param('Type') =~ m/TLG Word List/) 
	{
		if ($form->param('Just_Go'))
		{
			$handler{process_page_5}->();
		}
		else
		{
			$print_page_5->();
		}
	}
	elsif ($form->param('Type') !~ m/tlg/i) 
	{
		$print_page_3->();
	}
	else 
	{	
		$print_page_4->();
	}
};

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

# Here's where the real work gets done

# I don't think most browsers support changing the encoding of a single page
# in mid-stream, but let's try this anyway.  (Mozilla now does)

#my $charset = 'iso-8859-1';
my   $charset = 'UTF-8';

if ($form->param('greek_output_format') and
    $form->param('greek_output_format') =~ m/UTF-?8|Unicode/i)
{
    $charset = 'UTF-8';
    #$charset = 'iso-10646-1';
}
elsif ($form->param('greek_output_format') and
    $form->param('greek_output_format') =~ m/8859.?7/i)
{
    $charset = 'ISO-8859-7';
} 

if ($form->param('greek_output_format') and
    $form->param('greek_output_format') =~ m/PDF/i)
{
    # PDF is a special case: non-html
    print $form->header(-type=>'application/pdf');

    my $old_session = $form->param('session_num');
	open BETA, "<$tmp_prefix$old_session.bta" or die $!;
	binmode BETA;
	open TEX, ">$TMP.tex" or die $!;
	binmode TEX;
	my $old_fh = select TEX;
	my $formatter = new Diogenes(	'type' => 'none',
                                    'input_source' => \*BETA,
    								'output_format' => 'latex',
                                    'printer' => 1,
									'encoding' => 'Ibycus');
	$formatter->do_format;
	select $old_fh;
	close TEX or die $!;
		
	chdir $tmp_dir or die ("Couldn't chdir to $tmp_dir: $!");
	my $junk = `$latex \`\`\\\\scrollmode\\\\input $TMP.tex\'\'`;
    unlink "$TMP.tex" or die ("$!");
    system ($dvips, '-q', '-Pcmz', '-o', "$TMP.ps", "$TMP.dvi"); 
	unlink "$TMP.dvi" or die ("$!");
    system ($ps2pdf, "$TMP.ps", "$TMP.pdf"); 
	unlink "$TMP.ps" or die ("$!");
	print `cat $TMP.pdf`;
	unlink "$TMP.pdf" or die ("$!");
    exit;
}
else
{
#    $charset = qq{"\L$charset"};
    print $form->header(-type=>"text/html; charset=$charset");
}

if ($check_mod_perl and not $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/)
{
    $mod_perl_error->();
}
elsif (not $form->param('current_page')) 
{
	# First time, print opening page
	$print_splash_page->();
	$clean_garbage->();
}
else 
{
	$print_splash_page->() if $form->param('GoHome');
    
	# Data present, pass control to the appropriate subroutine
	my $sub_name;
	my $last_page = $form->param('current_page');
	$print_error_page->() unless $last_page;
	$print_error_page->() unless $last_page =~ m/\d\d?/;
	$print_error_page->() if ($last_page < 1 or $last_page > 16);
	# If the value of the hidden field called `current_page' is 1, then the
	# subroutine code reference is in $handler{process_page_1} and so forth ...
	$sub_name = "process_page_".$last_page;
	$handler{$sub_name}->();
}
# ex: set shiftwidth=4 tw=78 nowrap ts=4 si sta expandtab: #
