#!/usr/bin/perl -w

# This script is part of the Diogenes desktop application.  It
# converts texts to XML conforming to TEI version P5, as validated by
# Jing against the schema tei_all.rng, downloaded from the TEI
# website.  The script is normally executed from the integrated
# client/server application, but it can also be run from the command
# line.

# The default mode of operation is to use a pure-Perl XML manipulation
# library (XML::DOM::Lite), which is shipped with Diogenes, because
# that does not entail any additional binary dependencies for the
# desktop application.  But if installation of the XML::LibXML modules
# is detected, then libxml is used instead, because it is a bit
# faster.  The XML output from both modes of operation should be
# identical (please file a bug report if not).

# There are command-line switches to force use of XML::DOM:Lite or
# XML::LibXML.  When using libxml, additional functionality, which has
# not yet been ported to XML::DOM::Lite, is available via the command
# line.  These extra options increase the level of conformity with the
# TEI markup used by the DigiLibLT project; the XML export
# functionality in this script was initially developed at the request
# of and with the financial support of DigiLibLT.

use strict;
use warnings;
use Getopt::Std;
use File::Path;
use File::Spec;
use File::Basename;
use IO::Handle;
use File::Which;
use Encode;

use FindBin qw($Bin);
use File::Spec::Functions;
# Use local CPAN
use lib ($Bin, File::Spec->catdir($Bin, '..', 'dependencies', 'CPAN') );

use Diogenes::Base qw(%work %author %work_start_block %level_label
                      %database);
use Diogenes::Browser;
use Diogenes::BetaHtml;
use Diogenes::BetaXml;
my $resources = 'Diogenes-Resources';

$Getopt::Std::STANDARD_HELP_VERSION = 1;
sub VERSION_MESSAGE {print "xml-export.pl, Diogenes version $Diogenes::Base::Version\n"}
getopts ('alprho:c:sn:N:vdetx');
our ($opt_a, $opt_l, $opt_p, $opt_c, $opt_r, $opt_h, $opt_o, $opt_s, $opt_v, $opt_d, $opt_n, $opt_e, $opt_t, $opt_x, $opt_N);

sub HELP_MESSAGE {
    my $corpora = join ', ', sort values %Diogenes::Base::choices;
    print qq{
xml-export.pl is part of Diogenes; it converts classical texts in the
format develped by the Packard Humanities Institute (PHI) to XML files
conforming to the P5 specification of the Text Encoding Initiative
(TEI).

There are two mandatory switches:

-c abbr The abberviation of the corpus to be converted; without the -n
        option all authors will be converted.  Valid values are:
        $corpora

-o      Path to the parent of the output directory. If the supplied path
        contains a directory called $resources, only the
        components of the path up to that directory will be used; if
        it does not, $resources will be appended to the supplied
        path. $resources/xml is created if it does not exist, and
        within it a subdirectory with the abbreviated name of the
        corpus is created if it does not already exist.

By default, libxml2 is used if the associated Perl modules are
installed.  If not, DOM::XML::Lite, included with Diogenes, is used
instead.  This default can be overridden:

-x      Use DOM::XML::Lite even if XML:LibXML is installed.

Further optional switches are supported:

-v      Verbose info on progress of conversion and debugging
-n      Comma-separated list of author numbers to convert
-N      Author number to start at
-d      DigiLibLT compatibility; equal to -rpat (requires libxml)
-r      Convert book numbers to Roman numerals
-p      Mark paragraphs as milestones rather than divs (requires libxml)
-a      Suppress translating indentation into <space> tags
-l      Pretty-print XML using xmllint (requires libxml)
-s      Validate output against Relax NG Schema (via Jing;
          requires Java runtime)
-t      Translate div labels to DigiLibLT labels
-e      When using XML::DOM::Lite, do not convert hex entities to utf8
          (libxml2 insists upon converting to utf8)

};
}
my $debug = $opt_v ? 1 : 0;

use utf8;
binmode(STDERR, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");

# Default to use libxml if installed.
my $libxml = 1;
$libxml = 0 if $opt_x;
if ($libxml) {
    $libxml = require XML::LibXML;
    if ($libxml) {
        XML::LibXML->import( qw(:libxml) );
        print STDERR "LibXML installed.\n" if $debug;
    }
    else {
        print STDERR "LibXML not installed.\n" if $debug;
    }
}
if (not $libxml) {
    my $success = require XML::DOM::Lite;
    if ($success) {
        XML::DOM::Lite->import( qw(:constants) );
        $success = require XML::DOM::Lite::Extras;
        die "XML::DOM::Lite::Extras not found!\n" unless $success;
    }
    else {
        die "Neither libxml nor XML::DOM::Lite found!\n";
    }
}
if ($debug) {
    print STDERR $libxml ? "Using XML::LibXML.\n" : "Using XML::DOM::Lite.\n";
}

die "Error: specify corpus.\n" unless $opt_c;
my $corpus = $opt_c;
die "Unknown corpus.\n" unless exists $database{$corpus};
die "Error: specify output directory.\n" unless $opt_o;
if ($opt_d) {
    $opt_r = 1;
    $opt_p = 1;
    $opt_a = 1;
    $opt_t = 1;
}
die "Error: option -p currently requires libxml.\n" if $opt_p and not $libxml;
die "Error: option -e requires XML::DOM::Lite.\n" if $opt_e and $libxml;
die "Error: options -n and -N are incompatible.\n" if $opt_n and $opt_N;

# Output path
my $path;
my ($volume, $directories, $file) = File::Spec->splitpath( $opt_o );

if (-e $opt_o and not -d $opt_o) {
    # An existing file in a directory has been specified, so we assume that
    # the directory itself is meant.
    $path = $directories;
}
elsif ($file) {
    $path = File::Spec->catpath('', $directories, $file);
}
else {
    $path = $directories;
}
# If a directory called $resources is part of the path, use it,
# appending /xml; if not, append $resources/xml to the given path.
my @dirs = File::Spec->splitdir( $path );
my @newdirs;
for my $dir (@dirs) {
    last if $dir eq $resources;
    push @newdirs, $dir;
}
push @newdirs, $resources;
push @newdirs, 'xml';
push @newdirs, $corpus;
$path = File::Spec->catpath($volume, File::Spec->catdir(@newdirs), '');
unless (-e $path and -d $path) {
    File::Path->make_path($path) or die "Could not make output directory: $path.\n";
}

my $xmlns = 'http://www.tei-c.org/ns/1.0';

my $xml_header=qq{<?xml version="1.0" encoding="UTF-8"?>
<TEI xmlns="$xmlns">
  <teiHeader>
    <fileDesc>
      <titleStmt>
        <title>__TITLE__</title>
        <author>__AUTHOR__</author>
        <respStmt>
          <resp>Automated Conversion to XML</resp>
          <name>Diogenes</name>
        </respStmt>
      </titleStmt>
      <publicationStmt>
        <p>
          This XML text (filename __FILENAME__.xml) was generated by Diogenes (version __VERSION__) from the __CORPUS__ corpus of classical texts (author number __AUTHNUM__, work number __WORKNUM__), which was once distributed on CD-ROM in a very different file format, and which may be subject to licensing restrictions.
        </p>
      </publicationStmt>
      <sourceDesc>
        <p>
          __SOURCE__
        </p>
      </sourceDesc>
    </fileDesc>
  </teiHeader>
  <text>
    <body>
};

my $footer = q{
    </body>
  </text>
</TEI>
};

# Change English labels to conform with the Latinizing usage of DigiLibLT
my %div_translations = (
                        book => 'lib',
                        chapter => 'cap',
                        chap => 'cap',
                        section => 'par',
                        sect => 'par',
                        fragment => 'frag',
                        argument => 'arg',
                        declamation => 'decl',
                        fable => 'fab',
                        letter => 'epist',
                        life => 'vit',
                        name => 'nomen',
                        oration => 'orat',
                        page => 'pag',
                        play => 'op',
                        paradox => 'parad',
                        poem => 'carmen',
                        satire => 'sat',
                        sentence => 'sent',
                        sententia => 'sent',
                        title => 'cap',
                        verse => 'vers',
                        work => 'op',
                        addressee => 'nomen',
                        column => 'col',
);
use charnames qw(:full :short latin greek);

my $authtab = File::Spec->catfile( $path, 'authtab.xml' );
open( AUTHTAB, ">:encoding(UTF-8)", "$authtab" ) or die "Could not create $authtab\n";
AUTHTAB->autoflush(1);
print AUTHTAB qq{<authtab corpus="$corpus">\n};

my %args;
$args{type} = $corpus;
$args{encoding} = 'UTF-8';
$args{bib_info} = 1;
$args{perseus_links} = 0;

my $query = new Diogenes::Browser(%args);
my ($buf, $i, $auth_name, $real_num, $work_name, $body, $header, $is_verse, $hanging_div, $flag);

my @all_auths = sort keys %{ $Diogenes::Base::auths{$corpus} };
if ($opt_n) {
    if ($opt_n =~ m/,/) {
        @all_auths = split /,\s*/, $opt_n;
    }
    else {
        $opt_n =~ s/(\d+)/$1/;
        @all_auths = $opt_n;
    }
}
elsif ($opt_N) {
    my $num;
    while ($num = shift @all_auths) {
        last if $num >= $opt_N
    }
    unshift @all_auths, $num;
}

AUTH: foreach my $auth_num (@all_auths) {
    $real_num = $query->parse_idt ($auth_num);
    $query->{auth_num} = $auth_num;
    $auth_name = $Diogenes::Base::auths{$corpus}{$auth_num};
    my $lang = $Diogenes::Base::lang{$corpus}{$auth_num};
    if ($lang eq 'g') {
        $query->latin_with_greek(\$auth_name);
    }
    utf8::decode($auth_name);
    $auth_name = strip_formatting($auth_name);
    my $filename_in = $query->{cdrom_dir}.$query->{file_prefix}.
        $auth_num.$query->{txt_suffix};
    my $punct = q{_.;:!?};
    local undef $/;
    print "Author: $auth_name ($auth_num)\n" if $debug;
    open( IN, $filename_in ) or die "Could not open $filename_in\n";
    $buf = <IN>;
    close IN or die "Could not close $filename_in";
    print AUTHTAB qq{<author name="$auth_name" n="$auth_num">\n};
    $i = -1;
    my $body = '';
    my $line = '';
    my $chunk = '';
    my $hanging_div = '';
    my %old_levels = ();
    my %div_labels = ();
    my @relevant_levels = ();
    my @divs;
    my $work_num = 'XXXX';
    my $filename_out = '';
    while ($i++ <= length $buf) {
        my $char = substr ($buf, $i, 1);
        my $code = ord ($char);
        if ($code == hex 'f0' and ord (substr ($buf, ($i+1), 1)) == hex 'fe') {
            # End of file -- close out work
            $chunk .= $line;
            $body .= convert_chunk($chunk, $lang);
            $chunk = '';
            if ($is_verse) {
                $body .= "</l>\n";
            }
            else {
                $body .= "</p>\n";
            }
            $body .= "</div>\n" for (@divs);
            write_xml_file($filename_out, $header.$body.$footer);
            print AUTHTAB "</author>\n";
            next AUTH;
        }
        elsif ($code >> 7) {
            # Close previous line
            if ($hanging_div) {
                # Change to: We have come to the end of the line *after* the indication of a new prose div, and the previous line did not seem a suitable place to break (mainly for lack of punctuation.  If there is suitable punctuation in the current line, break there (after any trailing markup), preferring major punctuation to minor.  If there is no punctuation in the current line and the previous line did not end with a hyphen, break at the end of the previous line (suitable for cases when the div was not really hanging, such as for n="t" title sections).  If the previous line did end in a hyphen, break at the first comma, or, failing that, at the first space in the line.

                # If we come to the end of a line without finding
                # punctuation and we still have an prose div hanging
                # from the previous line, close the div out at start
                # of previous line.  This happens, e.g. when the div
                # was not really hanging as for n="t" title sections.
                if ($chunk =~ m/-\s*$/) {
                    # But first we check to make sure there is no
                    # hyphenation hanging over.  If so, break at a
                    # comma, or, failing that, at the first space in
                    # the line.
                    if ($line =~ m/(.*?),(.*)/) {
                        $chunk .= $1 . ',';
                        $line = $2;
                    }
                    elsif ($line =~ m/(\S+)\s+(.*)/) {
                        $chunk .= $1;
                        $line = $2;
                    }
                    else {
                        # We arrive here only in tlg1386016.xml,
                        # section 75, where one word is hyphenated
                        # twice, spanning three lines.  This results in
                        # an unavoidable hyphenation across sections.
                        # warn "No solution: $chunk \n\n$line\n";
                    }
                }
                $body .= convert_chunk($chunk, $lang);
                $chunk = '';
                $body .= $hanging_div;
                $hanging_div = '';
            }
            $chunk .= $line;
            $line = '';
            $query->parse_non_ascii(\$buf, \$i);
            my $new_div = -1;
            if (@relevant_levels and %old_levels) {
            LEVELS: foreach (@relevant_levels) {
                    if (exists $old_levels{$_} and exists $query->{level}{$_} and
                        $old_levels{$_} ne $query->{level}{$_}) {
                        $new_div = $_;
                        last LEVELS;
                    }
                }
            }
            %old_levels = %{ $query->{level} };
            if ($query->{work_num} ne $work_num) {
                # We have a new work
                if ($work_num ne 'XXXX') {
                    # Close out old work unless we have just started this author
                    $body .= convert_chunk($chunk, $lang);
                    $chunk = '';
                    if ($is_verse) {
                        $body .= "</l>\n";
                    }
                    else {
                        $body .= "</p>\n";
                    }
                    $body .= "</div>\n" for (@divs);
                    write_xml_file($filename_out, $header.$body.$footer);
                }
                $work_num = $query->{work_num};

                my %works =  %{ $work{$corpus}{$real_num} };
                $work_name = $works{$work_num};
                if ($lang eq 'g') {
                    $query->latin_with_greek(\$work_name);
                }
                utf8::decode($work_name);
                $work_name = strip_formatting($work_name);
                $query->{work_num} = $work_num;
                $filename_out = $corpus.$auth_num.$work_num.'.xml';
                my $source = $query->get_biblio_info($corpus, $auth_num, $work_num);
                if ($lang eq 'g') {
                    $query->latin_with_greek(\$source);
                }
                utf8::decode($source);
                $source = strip_formatting($source);
                $source =~ s#\s*\n\s*# #g;
                $body = '';
                $hanging_div = '';
                my @time = localtime(time);
                my $year = $time[5];
                $year += 1900;
                my $uppercase_corpus = uc($corpus);
                $header = $xml_header;
                $header =~ s#__AUTHOR__#$auth_name#;
                $header =~ s#__TITLE__#$work_name#;
                $header =~ s#__SOURCE__#$source#;
                $header =~ s#__CORPUS__#$uppercase_corpus#;
                $header =~ s#__AUTHNUM__#$auth_num#;
                $header =~ s#__WORKNUM__#$work_num#;
                $header =~ s#__FILENAME__#$corpus$auth_num$work_num#;
                $header =~ s#__YEAR__#$year#;
                $header =~ s#__VERSION__#$Diogenes::Base::Version#;

                $is_verse = is_work_verse($auth_num, $work_num);
                print "  Converting $work_name " .  ($is_verse ? "(lines)" : "(prose)") . " ($auth_num:$work_num).\n";
#                 print "$auth_num: $work_num, $is_verse\n" if $debug;
                %div_labels = %{ $level_label{$corpus}{$auth_num}{$work_num} };
                @divs = reverse sort numerically keys %div_labels;
                pop @divs, 1;
                @relevant_levels = @divs;
                push @relevant_levels, 0 if $is_verse;

                # TEI does not like spaces in the type attribute
                $div_labels{$_} =~ s/\s+/-/g foreach (keys %div_labels);

                if ($opt_t) {
                    for (keys %div_labels) {
                        if (exists $div_translations{$div_labels{$_}}) {
                            $div_labels{$_} =
                              $div_translations{$div_labels{$_}};
                        }
                    }
                }
                foreach (@divs) {
                    if ($opt_r and $div_labels{$_} eq 'lib') {
                        $body .= q{<div type="lib" n="}.roman($query->{level}{$_}).qq{">\n};
                    }
                    else {
                        my $n = $query->{level}{$_} || 1; # bug in phi2331025.xml
                        $body .= qq{<div type="$div_labels{$_}" n="$n">\n};
                    }
                }
                if ($is_verse) {
                    $body .= qq{<l n="$query->{level}{0}">};
                }
                else {
                    $body .= q{<p>};
                }
                print AUTHTAB qq{  <work name="$work_name" n="$work_num">\n};
                print AUTHTAB qq{    <div name="$div_labels{$_}"/>\n} for (@divs);
                print AUTHTAB qq{    <verse/>\n} if $is_verse;
            }
            elsif ($new_div >= 0) {
                # We have a new div or line of verse
                my $temp = $is_verse ? "</l>\n" : "</p>\n";
                $temp .= ("</div>\n" x $new_div);

                foreach (reverse 1 .. $new_div) {
                    if ($opt_r and $div_labels{$_} eq 'lib') {
                        $temp .= q{<div type="lib" n="}.roman($query->{level}{$_}).qq{">\n};
                    }
                    else {
                        $temp .= qq{<div type="$div_labels{$_}" n="$query->{level}{$_}">\n};
                    }
                }
                if ($is_verse) {
                    $temp .= qq{<l n="$query->{level}{0}">};
                }
                else {
                    $temp .= q{<p>};
                }
                # We seem to have a prose section which starts in the coming line
                if (((not $is_verse)
                     and ($chunk !~ m#[$punct][\s\$\&\"\d\@\}\]\>]*$#)
                     and ($chunk =~ m/\S/))
                    # Fragments are problematic should not hang from one to the next.
                    and (not ($div_labels{1} =~ m/frag/i and $query->{level}{0} eq '1'))
                    # But we need to rule out titles and headings, so
                    # we exclude "t" and where the section is back to 1
                    and (not ($query->{level}{1} and ($query->{level}{1} eq "1"
                                                      or $query->{level}{1} =~ m/t/)))
                    and (not ($query->{level}{2} and
                              ($query->{level}{2} =~ m/t/)))) {

                    $hanging_div = $temp;
                    $chunk .= "\n";
                }
                elsif ($chunk =~ m/\{\_\s*$/) {
                    # For divs that end with some text at eol that
                    # needs to go with the next div (e.g. {_ in
                    # Plato).
                    $chunk =~ s/(\{\_\s*)$//;
                    my $tmp = $1;
                    $body .= convert_chunk($chunk, $lang);
                    $chunk = $tmp;
                    $body .= $temp;
                }
                else {
                    # Verse, or a prose div that ends at the end of the current line, with suitable punctuation at its end.
                    $body .= convert_chunk($chunk, $lang);
                    $chunk = '';
                    $body .= $temp;
                }
            }
            else {
                # We have a line that can be added to the current chunk
                $chunk .= "\n";
            }
        }
        else {
            $line .= $char;
            # FIXME: remove this (move it earlier).
            if ($hanging_div and $char =~ m#[$punct]#) {
                # We have found a suitable punctuation mark to close
                # out a hanging prose div
                $chunk .= $line;
                $line = '';
                $body .= convert_chunk($chunk, $lang);
                $chunk = '';
                $body .= $hanging_div;
                $hanging_div = '';
            }
        }
    }
    # We never get here
}

print AUTHTAB "</authtab>\n";
close(AUTHTAB) or die "Could not close authtab.xml\n";

sub convert_chunk {

    my ($chunk, $lang) = @_;

    my %acute = (a => "\N{a with acute}", e => "\N{e with acute}", i => "\N{i with acute}", o => "\N{o with acute}", u => "\N{u with acute}", A => "\N{A with acute}", E => "\N{E with acute}", I => "\N{I with acute}", O => "\N{O with acute}", U => "\N{U with acute}");
    my %grave = (a => "\N{a with grave}", e => "\N{e with grave}", i => "\N{i with grave}", o => "\N{o with grave}", u => "\N{u with grave}", A => "\N{A with grave}", E => "\N{E with grave}", I => "\N{I with grave}", O => "\N{O with grave}", U => "\N{U with grave}");
    my %diaer = (a => "\N{a with diaeresis}", e => "\N{e with diaeresis}", i => "\N{i with diaeresis}", o => "\N{o with diaeresis}", u => "\N{u with diaeresis}", A => "\N{A with diaeresis}", E => "\N{E with diaeresis}", I => "\N{I with diaeresis}", O => "\N{O with diaeresis}", U => "\N{U with diaeresis}");
    my %circum = (a => "\N{a with circumflex}", e => "\N{e with circumflex}", i => "\N{i with circumflex}", o => "\N{o with circumflex}", u => "\N{u with circumflex}", A => "\N{A with circumflex}", E => "\N{E with circumflex}", I => "\N{I with circumflex}", O => "\N{O with circumflex}", U => "\N{U with circumflex}");
    my %ampersand = (1 => "bold", 2 => "bold italic", 3 => "italic", 4 => "superscript", 5 => "subscript", 7 => "small-caps", 8 => "small-caps italic", 10 => "small", 11 => "small bold", 12 => "small bold italic", 13 => "small italic", 14 => "small superscript", 15 => "small subscript", 16 => "superscript italic", 20 => "large ", 21 => "large bold", 22 => "large bold italic", 23 => "large italic", 24 => "large superscript", 25 => "large subscript", 30 => "very-small", 40 => "very-large");
    my %dollar = (1 => "bold", 2 => "bold italic", 3 => "italic", 4 => "superscript", 5 => "subscript", 6 => "superscript bold", 10 => "small", 11 => "small bold", 12 => "small bold italic", 13 => "small italic", 14 => "small superscript", 15 => "small subscript", 16 => "small superscript bold", 18 => "small", 20 => "large ", 21 => "large bold", 22 => "large bold italic", 23 => "large italic", 24 => "large superscript", 25 => "large subscript", 28 => "large", 30 => "very-small", 40 => "very-large");
    my %braces = (4 => "Unconventional-form", 5 => "Altered-form", 6 => "Discarded-form", 7 => "Discarded-reading", 8 => "Numerical-equivalent", 9 => "Alternate-reading", 10 => "Text-missing", 25 => "Inscriptional-form", 26 => "Rectified-form", 27 => "Alternate-reading", 28 => "Date", 29 => "Emendation", 44 => "Quotation", 45 => "Explanatory", 46 => "Citation", 48 => "Editorial-text", 70 => "Editorial-text", 71 => "Abbreviation", 72 => "Structural-note", 73 => "Musical-direction", 74 => "Cross-ref", 75 => "Image", 76 => "Cross-ref", 95 => "Colophon", 100 => "Added-text", 101 => "Original-text"  );

    # Fix bad hyphenation
    if ($auth_name eq 'Cassius Dio Hist. Dio Cassius') {
        # Capito- @1 {1[&Zonaras 7, 23.$]}1 &3lium, (across a div border)
        $chunk =~ s#(in praesidiis agebant ad Capito)-.*\z#$1lium, #gms;
        $chunk =~ s#\A.*?lium, (partim agrum vicinum populabantur)#$1#gms;
    }

    # Remove all hyphenation
    $chunk =~ s#(\S+)\-(\s*\@*\d*\s*)\n(\S+)#$1$3$2\n#g;

    # Fix missing Greek/Latin language switching indicators
    if ($auth_name eq 'Cyrillus Theol.') {
        $chunk =~ s#(\{1\&IN DANIELEM PROPHETAM\.)\>9\}1#$1\$\}1#gs;
        $chunk =~ s#\[\&cod\. A\.\>9\s*A\)KAKI\/AS\]#\[\&cod. A. \$A\)KAKI\/AS\]#gsm;
    }

    # Beta Greek to Unicode
    if ($lang eq 'g') {
        $query->greek_with_latin(\$chunk);
    }
    else {
        $query->latin_with_greek(\$chunk);
    }

    # Latin accents
    $chunk =~ s#([aeiouAEIOU])\/#$acute{$1}#g;
    $chunk =~ s#([aeiouAEIOU])\\#$grave{$1};#g;
    $chunk =~ s#([aeiouAEIOU])\=#$circum{$1}#g;
    $chunk =~ s#([aeiouAEIOU])\+#$diaer{$1}#g;

    # Convert utf8 bytes to utf8 characters, so that we match chars correctly.
    utf8::decode($chunk);

    # Escape XML reserved chars
    $chunk =~ s#\&#&amp;#g;
    $chunk =~ s#\<#&lt;#g;
    $chunk =~ s#\>#&gt;#g;

    # Fix ad-hoc special cases of improper nesting or missing markup
    # that will yield XML that is not well-formed.  We also
    # preemptively interfere in cases where our rearranging of font
    # commands below will have incorrect results.  We make these
    # changes early, because subsequent code will make the text harder
    # to match.
    if ($auth_name eq 'Sophocles Trag.') {
        # {$10*A.}
        $chunk =~ s#(\{\$10.*)\}(?!\$)#$1\$\}#gs;
    }
    elsif ($auth_name eq 'Aristophanes Comic.') {
        # {2<2$#15$3>2}2 and ^16<2_>2$3{2#523}2
        $chunk =~ s#\{2\&lt;2\$\#15\$3\&gt;2\}2#\{2\&lt;2\$\#15\&gt;2\}2#gs;
        $chunk =~ s#\$3\{2\#523\}2#\{2\#523\}2#gs;
    }
    elsif ($auth_name eq 'Scylax Perieg.') {
        $chunk =~ s#\$10Παλαίτυρος πόλις#Παλαίτυρος πόλις#gs;
    }
    elsif ($auth_name eq 'Aesopus Scr. Fab. et Aesopica') {
        # {1$10O)/NOS KAI\ LEONTH=}1 and {1$10LE/WN KAI\ TAU=ROI DU/O}1
        $chunk =~ s#\{1\$10(.*?[^\$])\}1#\{1\$10$1\$\}1#gs;
    }
    elsif ($auth_name eq 'Abydenus Hist.') {
        $chunk =~ s#\{1\&amp;ABYDENI#\&amp;`\{1\&amp;ABYDENI#gs;
    }
    elsif ($auth_name eq 'Ion Phil. et Poeta') {
        $chunk =~ s#\{1ΟΜΦΑΛΗ ΣΑΤΥΡΟΙ\}1\$10#\{1ΟΜΦΑΛΗ ΣΑΤΥΡΟΙ\}1`\$10#gs;
    }
    elsif ($auth_name eq 'Alcaeus Lyr.') {
        # <15[     $1]!W?N>15
        $chunk =~ s#(\$\d+[^\$]+)&gt;15#$1\$\&gt;15#gs;
        # $11<10!LO#7>10<11N?GA>11
        $chunk =~ s#\$11\&lt;10([^&]+)\&gt;10#\&lt;10\$11$1\$\&gt;10#gs;
        # <15$1THNAGXO?NH$6N$9$1>15 and <15$1]MELONTODEENEKE?![!!]!>15
        $chunk =~ s#(\&lt;15\$1)([^&]+)(&gt;15)#$1$2\$$3#gs;
    }
    elsif ($auth_name eq 'Cassius Dio Hist. Dio Cassius') {
        # {1$10 ... }1 -> should extend to whole contents
        $chunk =~ s#\{1\$10#\$10`\{1#gs;
        $chunk =~ s#\$10\{1#\$10`\{1#gs;
        $chunk =~ s#\}1\$#\}1`\$#gs;
    }
    elsif ($auth_name eq 'Eupolis Comic.') {
        # {2$#523$3}2
        $chunk =~ s#\$3\}2#\}2`\$3#gs;
    }
    elsif ($auth_name eq 'Heron Mech.') {
        # <70A B G ... KT$4A ... KD>70
        $chunk =~ s#(\&lt;70[^\$]*\$\d[^&]*)\&gt;70#$1\$\&gt;70#gs;
    }
    elsif ($auth_name eq 'Alexander Phil.') {
        # p. 47b15 ${1<20 ... }1
        $chunk =~ s#(\{1&lt;20[^\}]*)(\}1)#$1\&gt;20$2#gs;
    }
    elsif ($auth_name eq 'Lysias Orat.') {
        # $10 ... {1&PLATONICA.$}1
        $chunk =~ s#\{1\&amp;#\$`\{1\&amp;#gs;
    }
    elsif ($auth_name eq 'Menander Comic.') {
        $chunk =~ s#\{(ΨΕΥΔΗΡΑΚΛΗΣ\}1)#\{1$1#gs;
    }
    elsif ($auth_name eq 'Comica Adespota (CGFPR)') {
        # <2{_}>2$3{[ <- belongs outside
        $chunk =~ s#\$3\{\[#\$3\`\{\[#gs;
    }
    elsif ($auth_name eq 'Hierophilus Phil. et Soph.') {
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
    }
    elsif ($auth_name eq 'Anonyma De Musica Scripta Bellermanniana') {
        $chunk =~ s#\$1\&lt;4#\$1\`\&lt;4#gs;
    }
    elsif ($auth_name eq 'Democritus Phil.') {
        $chunk =~ s#\{1#\$\`\{1#gs;
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
        $chunk =~ s#\&lt;20(Ἠθικά|Ἀσύντακτα|Μαθηματικά|Μουσικά)\.#\&lt;20$1\.\&gt;20#gs;
    }
    elsif ($auth_name eq 'Historia Alexandri Magni') {
        $chunk =~ s#\&lt;13\{1(.*?)\}1#\{1$1\}1\`\&lt;13#gs;
    }
    elsif ($auth_name eq 'Pseudo-Auctores Hellenistae (PsVTGr)') {
        $chunk =~ s#\$\d\}1#\$\}1#gs;
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
    }
    elsif ($auth_name eq 'Vettius Valens Astrol.') {
        $chunk =~ s#(ἀστέρων|πλείους|μερισμοί)(\.(?:\]2)?\}1)#$1\&gt;20$2\&lt;20#gs;
    }
    elsif ($auth_name eq 'Eusebius Scr. Eccl. et Theol.') {
        $chunk =~ s#(ἐχθρούς σου ὑποπόδιον τῶν ποδῶν σου\.)#$1\$#gs;
    }
    elsif ($auth_name eq 'Porphyrius Phil.') {
        $chunk =~ s#\$10\&lt;10#\$10\`\&lt;10#gs;
        $chunk =~ s#\&gt;11\$#\&gt;11\`\$#gs;
    }
    elsif ($auth_name eq 'Athanasius Theol.') {
        $chunk =~ s#(κατὰ αἱρέσεων|ΗΜΩΝ ΑΘΑΝΑΣΙΟΥ|β\# λόγου|ΛΟΓΟΣ ΠΡΩΤΟΣ|λαϊκοὺς συνετέθη)\.\}1#$1\.\$\}1#gs;
        $chunk =~ s#(τὴν ἐμὴν ἀφίημι ὑμῖν\.)#$1\$#gs;
    }
    elsif ($auth_name eq 'Diophantus Math.') {
        $chunk =~ s#(\$\d*)(\&lt;34)#$1\`$2#gs;
    }
    elsif ($auth_name eq 'Basilius Theol.') {
        $chunk =~ s#(οὐ μὴ κριθῆτε\."6|Κεφάλ\. α\#.)(\}1)#$1\$$2#gs;
        $chunk =~ s#(\@ἐπαγγελίαν ἔχει\.)#$1\$#gs;
    }
    elsif ($auth_name eq 'Paulus Astrol.') {
        # <70{1 Heading stays inside Diagram (later changed to label)
        $chunk =~ s#\lt;70\{1#\lt;70\`\{1#gs;
    }
    elsif ($auth_name eq 'Socrates Scholasticus Hist.') {
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
    }
    elsif ($auth_name eq 'Joannes Chrysostomus Scr. Eccl. John Chrysostom') {
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
    }
    elsif ($auth_name eq 'Didymus Caecus Scr. Eccl. Didymus the Blind') {
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
        $chunk =~ s#(βροτοῖς ἀδίδακτος ἀκούει\.)#$1\$#gs;
    }
    elsif ($auth_name eq 'Hippolytus Scr. Eccl.') {
        $chunk =~ s#(\{1\$10(?:Ἱππολύτου|Ἀπολιναρίου)\.)\}1#$1\$\}1#gs;
    }
    elsif ($auth_name eq 'Timaeus Sophista Gramm.') {
        $chunk =~ s#(\$\d)(\&lt;9)#$1\`$2#gs;
    }
    elsif ($auth_name eq 'Gennadius I Scr. Eccl.') {
        $chunk =~ s#(Gal 4,17)\$10\}1#$1\}1\$10#gs;
    }
    elsif ($auth_name eq 'Basilius Scr. Eccl.') {
        $chunk =~ s#(Λόγος γ\#\.)\}1#$1\$\}1#gs;
    }
    elsif ($auth_name eq 'Oecumenius Phil. et Rhet.') {
        $chunk =~ s#(Phil 3,14|Thess 2,16|Tim 5,10|Tit 1,12|Hebr 2,14|Hebr 5,1)\$10\}1#$1\$\}1#gs;
    }
    elsif ($auth_name eq 'Joannes Damascenus Scr. Eccl. et Theol. John of Damascus') {
        $chunk =~ s#(τοῦ Διαιτητοῦ)\.\}1#$1\.\$\}1#gs;
    }
    elsif ($auth_name eq 'Symeon Metaphrastes Biogr. et Hist.') {
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
    }
    elsif ($auth_name eq 'Anonymi In Aristotelis Ethica Nicomachea Phil.') {
        # In retrospect, should have just deleted all of the <20 >20.
        $chunk =~ s#(\[2κεφ\. ζ\#\.\]2)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(ἑαυτὰ ἀγαθῶν\. κεφ\. θ\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(τιμίων ἡ εὐδαιμονία\. κεφ\. ιθ\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(ἐλλείψεως φθείρονται\. κεφ\. β\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#\{1(Περὶ τῆς ἐναντιότητος τῶν)#\&gt;20\{1\&lt;20$1#gs;
        $chunk =~ s#(τῆς μεσότητος τυγχάνειν\. κεφ\. η\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(Περὶ ἀνδρείας\. κεφ\. η\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#\{1(Περὶ ἀνδρείας, ὅτι ὁ ἀνδρεῖος περὶ τὰ φοβερὰ)#\&gt;20\{1\&lt;20$1#gs;
        $chunk =~ s#(Περὶ σωφροσύνης\. κεφ\. ι\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(ἡ σωφροσύνη καὶ ἡ ἀκολασία\. \nκεφ\. ιβ\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#\{1(Ὅτι ἡ ἀκολασία μᾶλλον ἑκούσιόν ἐστιν)#\&gt;20\{1\&lt;20$1#gs;
        $chunk =~ s#(Περὶ μεγαλοπρεπείας. κεφ. γ\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(ἀδικεῖν καὶ μὴ ἄδικον εἶναι. κεφ. η\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(\{1\&lt;20Περὶ φρονήσεως. κεφ.)#\&gt;20$1#gs;
        $chunk =~ s#(Περὶ φιλίας. κεφ. α\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(ἐνεργείᾳ φίλοις \nεἶναι\. κεφ\. \#2\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
        $chunk =~ s#(Περὶ ἡδονῆς. κεφ. α\#\.)\}1#$1\&gt;20\}1\&lt;20#gs;
    }
    elsif ($auth_name eq 'Michael Phil.') {
        $chunk =~ s#(παρὰ τὸ προστιθέναι τι συλλογίζονται\.)\}1#$1\&gt;20\}1\&lt;20#gs;
    }
    elsif ($auth_name eq 'Proclus Phil.') {
        # These do not nest at all within their diagram
        $chunk =~ s#\$10#\$#gs;
        $chunk =~ s#(ἐνεργείαις τελειότητος)#$1\$#gs;
    }
    elsif ($auth_name eq 'Theophanes Confessor Chronogr.') {
        $chunk =~ s#\$10#\$#gs;
    }
    elsif ($auth_name eq 'Theodoretus Scr. Eccl. et Theol.') {
        $chunk =~ s#(?<!\$)\}1#\$\}1#gs;
        $chunk =~ s#(ἀποκαλύψεις ἡρμήνευσε\.)#$1\$#gs;
    }
    elsif ($auth_name eq 'Cyrillus Theol.') {
        $chunk =~ s#\$10\}3#\}3\$10#gs;
        $chunk =~ s#\{1ΨΑΛΜΟΣ Λ\#2\&gt;9\}1#\{1ΨΑΛΜΟΣ Λ\#2\}1#gs;
        $chunk =~ s#(\@τῇ σαρκί μου\.)(\&gt;9)#$1\$$2#gs;
        $chunk =~ s#\{1\&lt;9ΨΑΛΜΟΣ ΜΕ\#\.\}1#\{1ΨΑΛΜΟΣ ΜΕ\#\.\}1#gs;
        $chunk =~ s#(Εὐφράνθητε, δίκαιοι, ἐν τῷ Κυρίῳ\.)\&gt;9#$1#gs;
        $chunk =~ s#(εἰς μετοικίαν πορεύσεται\.)\&gt;9#$1#gs;
        $chunk =~ s#(Πνεύματος εἰς τὴν Γαλιλαίαν\.)\&gt;9#$1#gs;
        $chunk =~ s#(καὶ Σίμων, \$3ὑπακοή\.)\&gt;9#$1#gs;
        $chunk =~ s#(τὸν Σατανᾶν, κ\.τ\.λ\.)\&gt;9#$1#gs;
        $chunk =~ s#(ὁ πλούσιος, καὶ ἐτάφη, κ\.τ\.λ\.)\&gt;9#$1#gs;
        $chunk =~ s#(\{1ΚΕΦΑΛ. ΚΑ\#\.)\&gt;9\}1#$1\}1#gs;
        $chunk =~ s#(ὢν, οὐ ψεύδεται\.)\&gt;9#$1#gs;
        $chunk =~ s#(καὶ ὅσα τούτοις ὅμοια\.)\}1#$1\$\}1#gs;
    }
    elsif ($auth_name eq 'Georgius Choeroboscus Gramm.') {
        $chunk =~ s#(πώεος τοῦ γόνυος)\&gt;20( καὶ )\&lt;20(γουνός)#$1$2$3#gs;
    }
    elsif ($auth_name eq 'Catenae (Novum Testamentum)') {
        $chunk =~ s#(συμβουλευτικῆς πρὸς σωτηρίαν αὐτῶν\.)\}1#$1\$\}1#gs;
        $chunk =~ s#(καὶ ἀνανεώσεως τῶν Ἀποστόλων\.)\}1#$1\$\}1#gs;
        $chunk =~ s#(ἀκωλύτως κηρύσσειν τὸν Χριστόν\.)\}1#$1\$\}1#gs;
        $chunk =~ s#(Περὶ χειροτονίας τῶν ἑπτὰ Διακόνων\.)\}1#$1\$\}1#gs;
        $chunk =~ s#(μαστίξαντες ἀπέλυσαν\.)#$1\$#gs;
    }
    elsif ($auth_name eq 'Diodorus Scr. Eccl.') {
        $chunk =~ s#(\{1\&amp;Röm 9,11)\$10\}1#$1\}1#gs;
    }
    elsif ($auth_name eq 'Severianus Scr. Eccl.') {
        $chunk =~ s#(\&amp;Röm 4,20)\$10#$1#gs;
        $chunk =~ s#(\&amp;\`1 Kor 7,17)\$10#$1#gs;
        $chunk =~ s#(\&amp;\`1 Kor 15,19)\$10#$1#gs;
    }
    elsif ($auth_name eq 'Commentaria In Dionysii Thracis Artem Grammaticam') {
        $chunk =~ s#(Σ\&amp;4d)(?!\&amp;)#$1\&amp;#gs;
        $chunk =~ s#(μέσων, οἷον ἕβδομος ὄγδοος\.)#$1\$#gs;
        $chunk =~ s#(Θεῷ εἰς τὰ προλεγόμενα τῆς γραμματικῆς)\&gt;20#$1#gs;
        $chunk =~ s#(hymn\. in Merc\. 263\%1\]2\$)10#$1#gs;
        $chunk =~ s#(\$10\s*Περὶ γραμματικῆς\.)\}1#$1\$\}1#gs;
        $chunk =~ s#\$10##gs;  # I give up
        $chunk =~ s#(\{1\§\s)\&amp;#\$\`$1#gs;
        $chunk =~ s#(\§\s)\&amp;(\`12)#$1$2#gs;
    }

    # $flag = 1 if $chunk =~ m/Περὶ ἀμύλου\./;
    # $flag = 0 if $chunk =~ m/Περὶ κριθίνων ἄρτων\./;
    # print STDERR ">>$chunk\n\n" if $flag;


    # Font switching.

    # These numbered font commands must be treated as plain & or $
    $chunk =~ s#\&amp;(6|9|19)#\&amp;#g;
    $chunk =~ s#\$(8|9|18|70)#\$#g;

    # Improperly nested font-switching markup is ubiquitous: e.g. {&7
    # ... }&; {40&7 ... }40&; <20$10{1*GELW/|WN.>20$}1. We deal with
    # this by standardising the nesting order when the markup is
    # consecutive.  From outer to inner: braces, angle brackets, font
    # switching.  We thus bring leading font commands into the brace
    # construction and also trailing non-numbered font commands.  When
    # the closing brace is followed by a numbered font changing
    # command, we insert a return to the baseline font just before the brace.
    # We also bring <> starting tags inside any {} and bring fonts
    # inside <> just as for {}.  Problems arising from this approach
    # are treated as ad-hoc exceptions above, where we insert a back-tick
    # to separate elements of markup that we do not want to swap in.

    $chunk =~ s#((?:\$|\&amp;)\d*)(\{\d*)#$2$1#gs;
    $chunk =~ s#(\}\d*)(\$|\&amp;)(?!\d)#$2$1#gs;
    $chunk =~ s#(\}\d*)(\$|\&amp;)(?=\d)#$2$1$2#gs;
    $chunk =~ s#(\&lt;\d*)(\{\d*)#$2$1#gs;
    $chunk =~ s#(\}\d*)(\&gt;\d*)#$2$1#gs;
    $chunk =~ s#((?:\$|\&amp;)\d*)(\&lt;\d*)#$2$1#gs;
    $chunk =~ s#(\&gt;\d*)(\$|\&amp;)(?!\d)#$2$1#gs;
    $chunk =~ s#(\&gt;\d*)(\$|\&amp;)(?=\d)#$2$1$2#gs;

    # Font markup is terminated by next change of font or return to
    # normal font or end of chunk.
    $chunk =~ s#\&amp;(\d+)(.*?)(?=\$|\&amp;|\z)#exists
        $ampersand{$1} ? qq{<hi rend="$ampersand{$1}">$2</hi>} : qq{$2}#ges;

    $chunk =~ s#\$(\d+)(.*?)(?=\$|\&amp;|\z)#exists
                        $dollar{$1} ? qq{<hi rend="$dollar{$1}">$2</hi>} : qq{$2}#ges;

    # The look-ahead assertion above deliberately does not capture
    # trailing font-change indicators, in order that they can also
    # match as the beginning of the next font change.  This behind
    # leaves many indicators of a return to the normal font ($ and &),
    # which do not thus match to start a new range of markup. So we
    # have to remove these at the end.

    if ($debug) {
        print STDERR "Unmatched markup: $1\n$chunk\n\n" if $chunk =~ m/((?:\$|&amp;)\d+)/;
        $chunk =~ s#\&amp;(?!\d)##g;
        $chunk =~ s#\$(?!\d)##g;
    }
    else {
        $chunk =~ s#\&amp;\d*##g;
        $chunk =~ s#\$\d*##g;
    }

    #### Balanced markup

    # Font commands are a state machine rather than balanced markup,
    # but {} and <> are different: they are supposed to be balanced
    # (we can ignore [] variants, as these are punctuation rather than
    # markup).  Markup with {} and <> is not always balanced,
    # sometimes by error, sometimes because of deliberately eccentric
    # markup, sometimes because the chunking has cut across a balanced
    # pair, which is especially common when the structural citation
    # scheme follows the pagination of an edition (e.g Stephanus, but
    # also for many theological texts).  The chunking problem could be
    # eliminated if all structural markup were turned into milestones
    # (which can be spanned by tags) rather than divs.  But this would
    # badly violate the spirit if not the letter of the TEI
    # guidelines.

    # When a balanced pair has been split by chunking into divs, the
    # correct solution is to create two spans: one from the opening to
    # the end of the div and the second from the start of the new div
    # to the closing.  But this is problematic in the case of
    # unbalanced markup that is the result not of chunking but of
    # error or a deliberate practice of unbalanced markup.  It can
    # result in many large spans incorrectly marked up and a pile-up
    # of spurious markup at the start and end of divs.

    # For practical reasons, what we do here is to apply only to
    # markup with braces {} the treatment of extending an unpaired
    # start or end brace to the beginning or end of the chunk.  Braces
    # tend to be structural and are used more sparingly and carefully.
    # By contrast, markup with angle brackets <> is mainly
    # typographical and is more carelessly deployed.  In some cases,
    # this is clearly intended (as when opening markup is repeated at
    # the start of every line, with the closing markup only at the end
    # of the passage).  Thus there is a large amount of stray
    # unbalanced <> markup which is not due to chunking, and it would
    # not be desirable to span from all of these to the beginning or
    # end of the chunk.  On the other hand, it would not be right to
    # remove the unbalanced markup entirely.  So as a compromise, for
    # unpaired <> markup, we proceed more cautiously, matching only up
    # to the next/previous XML tag.  This should minimize the amount
    # of unbalanced markup and large spurious spans created by this
    # guesswork.  But it does mean that where balanced <> markup has
    # been split by chunking, it means that there will be cases where
    # the spans are not as long as they should be and there is a gap
    # in the middle.

    # To summarize, we match paired {} and <> within chunks freely.
    # For leftover unpaired braces, we match to the start/end of
    # chunk.  For leftover unpaired angle brackets, we match only to
    # the next/previous XML markup. In this final case, order of
    # matching is important, as earlier matched constructions will
    # create XML tags that will interfere with subsequent spans.
    # Despite these precautions, there are texts that need ad-hoc
    # fixes to avoid generating ill-formed XML.

    #### {} Titles, marginalia, misc.

    # Fix unbalanced markup ??
#    $chunk =~ s/{2\@{2#10}2/{2#10/g;

    # Elements other than plain <seg>

    # Heads
    $chunk =~ s#\{1(?!\d)(.*?)\}1(?!\d)#<head>$1</head>#gs;
    # Unbalanced heads.
    $chunk =~ s#\{1(?!\d)(.*?)\z#<head>$1</head>#gms;
    $chunk =~ s#\A(.*?)\}1(?!\d)#<head>$1</head>#gms;

    # Marginalia
    $chunk =~ s#\{2(?!\d)(.*?)\}2(?!\d)#<seg rend="Marginalia">$1</seg>#gs;
    $chunk =~ s#\{2(?!\d)(.*?)\z#<seg rend="Marginalia">$1</seg>#gs;
    $chunk =~ s#\A(.*?)\}2(?!\d)#<seg rend="Marginalia">$1</seg>#gs;

    $chunk =~ s#\{90(.*?)\}90#<seg rend="Marginalia">$1</seg>#gs;
    $chunk =~ s#\{90(.*?)\z#<seg rend="Marginalia">$1</seg>#gs;
    $chunk =~ s#\A(.*?)\}90#<seg rend="Marginalia">$1</seg>#gs;

    $chunk =~ s#\{3(?!\d)(.*?)\}3(?!\d)#<ref>$1</ref>#gs;
    $chunk =~ s#\{3(?!\d)(.*?)\z#<ref>$1</ref>#gs;
    $chunk =~ s#\A(.*?)\}3(?!\d)#<ref>$1</ref>#gs;

    # Speakers, etc.

    # No number: usually speakers in drama, pastoral, etc.
    $chunk =~ s#\{(?!\d)(.*?)\}(?!\d)#<label type="speaker">$1</label>#gs;
    $chunk =~ s#\{(?!\d)(.*?)\z#<label type="speaker">$1</label>#gs;
    $chunk =~ s#\A(.*?)\}(?!\d)#<label type="speaker">$1</label>#gs;

    $chunk =~ s#\{([48]0)(.*?)\}\g1#<label type="speaker">$2</label>#gs;
    $chunk =~ s#\{[48]0(.*?)\z#<label type="speaker">$1</label>#gs;
    $chunk =~ s#\A(.*?)\}[48]0#<label type="speaker">$1</label>#gs;

    $chunk =~ s#\{41(.*?)\}41#<label type="stage-direction">$1</label>#gs;
    $chunk =~ s#\{41(.*?)\z#<label type="stage-direction">$1</label>#gs;
    $chunk =~ s#\A(.*?)\}41#<label type="stage-direction">$1</label>#gs;

    # Servius
    $chunk =~ s#\[2{43#{43\[2#g; # Fix improper nesting
    $chunk =~ s#\{43(.*?)\}43#<seg type="Danielis" rend="italic">$1</seg>#gs;

    # All other types of braces, using <seg>
    $chunk =~ s#\{(\d+)(.*?)\}\g1#exists
                      $braces{$1} ? qq{<seg type="$braces{$1}">$2</seg>} : qq{<seg type="Non-text-characters">$2</seg>}#ges;

    $chunk =~ s#\{(\d+)(.*?)\}\z#exists
                      $braces{$1} ? qq{<seg type="$braces{$1}">$2</seg>} : qq{<seg type="Non-text-characters">$2</seg>}#ges;

    $chunk =~ s#\A(.*?)\}(\d+)#exists
                      $braces{$2} ? qq{<seg type="$braces{$2}">$1</seg>} : qq{<seg type="Non-text-characters">$1</seg>}#ges;

    if ($debug) {
        print STDERR "Unmatched markup: $1\n$chunk\n\n" if $chunk =~ m/([{}]\d*)/;
    }
    else {
        # Clean up any unmatched braces
        $chunk =~ s#\}\d*##g;
        $chunk =~ s#\{\d*##g;
    }

    #### <> Text decoration

    # Some of these do not nest properly with respect to font changes:
    # e.g "HS &7<ccc&>".  This problem can be evaded by using <hi>
    # elements for both, so that the group ends with </hi></hi>.

    # Matching for paired <> markup only

    $chunk =~ s#&lt;(?!\d)(.*?)&gt;(?!\d)#<hi rend="overline">$1</hi>#gs;
    $chunk =~ s#&lt;1(?!\d)(.*?)&gt;1(?!\d)#<hi rend="underline">$1</hi>#gs;
    $chunk =~ s/&lt;3(?!\d)(.)(.*?)&gt;3(?!\d)/$1&#x0361;$2/gs;
    $chunk =~ s/&lt;4(?!\d)(.)(.*?)&gt;4(?!\d)/$1&#x035C;$2/gs;
    $chunk =~ s/&lt;5(?!\d)(.)(.*?)&gt;5(?!\d)/$1&#x035D;$2/gs;
    $chunk =~ s#&lt;6(?!\d)(.*?)&gt;6(?!\d)#<hi rend="superscript">$1</hi>#gs;
    $chunk =~ s#&lt;7(?!\d)(.*?)&gt;7(?!\d)#<hi rend="subscript">$1</hi>#gs;
    $chunk =~ s#&lt;8(?!\d)(.*?)&gt;8(?!\d)#<hi rend="double-underline">$1</hi>#gs;
    $chunk =~ s#&lt;9(?!\d)(.*?)&gt;9(?!\d)#<seg type="lemma" rend="bold">$1</seg>#gs;
    $chunk =~ s#&lt;10(?!\d)(.*?)&gt;10(?!\d)#<seg rend="Stacked-text-lower">$1</seg>#gs;
    $chunk =~ s#&lt;11(?!\d)(.*?)&gt;11(?!\d)#<seg rend="Stacked-text-upper">$1</seg>#gs;
    $chunk =~ s#&lt;12(?!\d)(.*?)&gt;12(?!\d)#<seg rend="Non-standard-text-direction">$1</seg>#gs;
    $chunk =~ s#&lt;13(?!\d)(.*?)&gt;13(?!\d)#<seg rend="Single-spacing">$1</seg>#gs;
    $chunk =~ s#&lt;14(?!\d)(.*?)&gt;14(?!\d)#<seg rend="Interlinear-text">$1</seg>#gs;
    $chunk =~ s#&lt;15(?!\d)(.*?)&gt;15(?!\d)#<seg rend="Marginalia">$1</seg>#gs;
    $chunk =~ s#&lt;17(?!\d)(.*?)&gt;17(?!\d)#<hi rend="double-underline">$1</hi>#gs;
    $chunk =~ s#&lt;18(?!\d)(.*?)&gt;18(?!\d)#<hi rend="line-through">$1</hi>#gs;
    $chunk =~ s#&lt;2([01])(?!\d)(.*?)&gt;2\g1(?!\d)#<hi rend="letter-spacing">$2</hi>#gs;
    $chunk =~ s#&lt;30(?!\d)(.*?)&gt;30(?!\d)#<hi rend="overline">$1</hi>#gs;
    $chunk =~ s#&lt;31(?!\d)(.*?)&gt;31(?!\d)#<hi rend="line-through">$1</hi>#gs;
    $chunk =~ s#&lt;32(?!\d)(.*?)&gt;32(?!\d)#<hi rend="overline underline">$1</hi>#gs;
    $chunk =~ s/&lt;33(?!\d)(.*?)&gt;33(?!\d)/<hi rend="overline">&#x221A;$1<\/hi>/gs;
    $chunk =~ s/&lt;34(?!\d)(.*?)\%3(.*?)&gt;34(?!\d)/<hi rend="superscript">$1<\/hi>&#x2044;<hi rend="subscript">$2<\/hi>/gs;
    $chunk =~ s/&lt;5(\d)(?!\d)(.*?)&gt;5\g1(?!\d)/<seg type="Unknown">$2<\/seg>/gs;
    $chunk =~ s/&lt;60(?!\d)(.*?)&gt;60(?!\d)/<seg type="Preferred-text">$1<\/seg>/gs;
    $chunk =~ s/&lt;61(?!\d)(.*?)&gt;61(?!\d)/<seg type="Post-erasure">$1<\/seg>/gs;
    $chunk =~ s/&lt;62(?!\d)(.*?)&gt;62(?!\d)/<hi rend="overline">$1<\/hi>/gs;
    $chunk =~ s/&lt;63(?!\d)(.*?)&gt;63(?!\d)/<seg type="Post-correction">$1<\/seg>/gs;
    $chunk =~ s/&lt;(6[45])(?!\d)(.*?)&gt;\g1(?!\d)/<hi rend="boxed">$2<\/hi>/gs;
    $chunk =~ s/&lt;(6[6789])(?!\d)(.*?)&gt;\g1(?!\d)/<seg type="Unknown">$2<\/seg>/gs;
    $chunk =~ s/&lt;70(?!\d)(.*?)&gt;70(?!\d)/<seg type="Diagram">$1<\/seg>/gs;
    $chunk =~ s/&lt;71(?!\d)(.*?)&gt;71(?!\d)/<seg type="Diagram-section">$1<\/seg>/gs;
    $chunk =~ s/&lt;72(?!\d)(.*?)&gt;72(?!\d)/<seg type="Diagram-caption">$1<\/seg>/gs;
    $chunk =~ s/&lt;73(?!\d)(.*?)&gt;73(?!\d)/<seg type="Diagram-level-3">$1<\/seg>/gs;
    $chunk =~ s/&lt;74(?!\d)(.*?)&gt;74(?!\d)/<seg type="Diagram-level-4">$1<\/seg>/gs;
    $chunk =~ s#&lt;90(?!\d)(.*?)&gt;90(?!\d)#<seg type="Non-standard-text-direction">$1</seg>#gs;
    $chunk =~ s#&lt;100(?!\d)(.*?)&gt;100(?!\d)#<hi rend="line-through">$1</hi>#gs;

    # Unpaired <> markup.  We only match to next/previous XML tag.
    # Order is significant: from most likely to be long spans to
    # shorter.  We want to first match the tags that are likely to
    # have the largest scope, so that the matching of smaller elements
    # does not interfere with the larger ones.  Where this results in
    # an empty element, we leave it there as a signal that something
    # may have been missed out.

    $chunk =~ s#&lt;12(?!\d)([^<>]*?)#<seg rend="Non-standard-text-direction">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;12(?!\d)#<seg rend="Non-standard-text-direction">$1</seg>#gs;

    $chunk =~ s#&lt;90(?!\d)([^<>]*?)#<seg type="Non-standard-text-direction">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;90(?!\d)#<seg type="Non-standard-text-direction">$1</seg>#gs;

    $chunk =~ s#&lt;2[01](?!\d)([^<>]*?)#<hi rend="letter-spacing">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;2[01](?!\d)#<hi rend="letter-spacing">$1</hi>#gs;

    $chunk =~ s/&lt;70(?!\d)([^<>]*?)/<seg type="Diagram">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;70(?!\d)/<seg type="Diagram">$1<\/seg>/gs;

    $chunk =~ s/&lt;71(?!\d)([^<>]*?)/<seg type="Diagram-section">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;71(?!\d)/<seg type="Diagram-section">$1<\/seg>/gs;

    $chunk =~ s/&lt;72(?!\d)([^<>]*?)/<seg type="Diagram-caption">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;72(?!\d)/<seg type="Diagram-caption">$1<\/seg>/gs;

    $chunk =~ s/&lt;73(?!\d)([^<>]*?)/<seg type="Diagram-level-3">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;73(?!\d)/<seg type="Diagram-level-3">$1<\/seg>/gs;

    $chunk =~ s/&lt;74(?!\d)([^<>]*?)/<seg type="Diagram-level-4">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;74(?!\d)/<seg type="Diagram-level-4">$1<\/seg>/gs;

    $chunk =~ s#&lt;9(?!\d)([^<>]*?)#<seg type="lemma" rend="bold">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;9(?!\d)#<seg type="lemma" rend="bold">$1</seg>#gs;

    $chunk =~ s#&lt;13(?!\d)([^<>]*?)#<seg rend="Single-spacing">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;13(?!\d)#<seg rend="Single-spacing">$1</seg>#gs;

    $chunk =~ s#&lt;14(?!\d)([^<>]*?)#<seg rend="Interlinear-text">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;14(?!\d)#<seg rend="Interlinear-text">$1</seg>#gs;

    $chunk =~ s#&lt;10(?!\d)([^<>]*?)#<seg rend="Stacked-text-lower">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;10(?!\d)#<seg rend="Stacked-text-lower">$1</seg>#gs;

    $chunk =~ s#&lt;11(?!\d)([^<>]*?)#<seg rend="Stacked-text-upper">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;11(?!\d)#<seg rend="Stacked-text-upper">$1</seg>#gs;

    $chunk =~ s#&lt;15(?!\d)([^<>]*?)#<seg rend="Marginalia">$1</seg>#gs;
    $chunk =~ s#([^<>]*?)&gt;15(?!\d)#<seg rend="Marginalia">$1</seg>#gs;

    $chunk =~ s#&lt;(?!\d)([^<>]*?)#<hi rend="overline">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;(?!\d)#<hi rend="overline">$1</hi>#gs;

    $chunk =~ s#&lt;1(?!\d)([^<>]*?)#<hi rend="underline">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;1(?!\d)#<hi rend="underline">$1</hi>#gs;

    $chunk =~ s#&lt;8(?!\d)([^<>]*?)#<hi rend="double-underline">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;8(?!\d)#<hi rend="double-underline">$1</hi>#gs;

    $chunk =~ s#&lt;17(?!\d)([^<>]*?)#<hi rend="double-underline">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;17(?!\d)#<hi rend="double-underline">$1</hi>#gs;

    $chunk =~ s#&lt;18(?!\d)([^<>]*?)#<hi rend="line-through">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;18(?!\d)#<hi rend="line-through">$1</hi>#gs;

    $chunk =~ s#&lt;30(?!\d)([^<>]*?)#<hi rend="overline">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;30(?!\d)#<hi rend="overline">$1</hi>#gs;

    $chunk =~ s#&lt;31(?!\d)([^<>]*?)#<hi rend="line-through">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;31(?!\d)#<hi rend="line-through">$1</hi>#gs;

    $chunk =~ s#&lt;32(?!\d)([^<>]*?)#<hi rend="overline underline">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;32(?!\d)#<hi rend="overline underline">$1</hi>#gs;

    $chunk =~ s/&lt;33(?!\d)([^<>]*?)/<hi rend="overline">&#x221A;$1<\/hi>/gs;
    $chunk =~ s/([^<>]*?)&gt;33(?!\d)/<hi rend="overline">&#x221A;$1<\/hi>/gs;

    $chunk =~ s#&lt;6(?!\d)([^<>]*?)#<hi rend="superscript">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;6(?!\d)#<hi rend="superscript">$1</hi>#gs;

    $chunk =~ s#&lt;7(?!\d)([^<>]*?)#<hi rend="subscript">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;7(?!\d)#<hi rend="subscript">$1</hi>#gs;

    $chunk =~ s/&lt;34(?!\d)([^<>]*?)/<hi rend="superscript">$1<\/hi>&#x2044;<hi rend="subscript">$2<\/hi>/gs;
    $chunk =~ s/([^<>]*?)&gt;34(?!\d)/<hi rend="superscript">$1<\/hi>&#x2044;<hi rend="subscript">$2<\/hi>/gs;

    $chunk =~ s/&lt;5\d(?!\d)([^<>]*?)/<seg type="Unknown">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;5\d(?!\d)/<seg type="Unknown">$2<\/seg>/gs;

    $chunk =~ s/&lt;60(?!\d)([^<>]*?)/<seg type="Preferred-text">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;60(?!\d)/<seg type="Preferred-text">$1<\/seg>/gs;

    $chunk =~ s/&lt;61(?!\d)([^<>]*?)/<seg type="Post-erasure">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;61(?!\d)/<seg type="Post-erasure">$1<\/seg>/gs;

    $chunk =~ s/&lt;62(?!\d)([^<>]*?)/<hi rend="overline">$1<\/hi>/gs;
    $chunk =~ s/([^<>]*?)&gt;62(?!\d)/<hi rend="overline">$1<\/hi>/gs;

    $chunk =~ s/&lt;63(?!\d)([^<>]*?)/<seg type="Post-correction">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;63(?!\d)/<seg type="Post-correction">$1<\/seg>/gs;

    $chunk =~ s/&lt;6[45](?!\d)([^<>]*?)/<hi rend="boxed">$1<\/hi>/gs;
    $chunk =~ s/([^<>]*?)&gt;6[45](?!\d)/<hi rend="boxed">$1<\/hi>/gs;

    $chunk =~ s/&lt;6[6789](?!\d)([^<>]*?)/<seg type="Unknown">$1<\/seg>/gs;
    $chunk =~ s/([^<>]*?)&gt;6[6789](?!\d)/<seg type="Unknown">$1<\/seg>/gs;

    $chunk =~ s#&lt;100(?!\d)([^<>]*?)#<hi rend="line-through">$1</hi>#gs;
    $chunk =~ s#([^<>]*?)&gt;100(?!\d)#<hi rend="line-through">$1</hi>#gs;

    $chunk =~ s/&lt;2(?!\d)/&#x2035;/g;
    $chunk =~ s/&gt;2(?!\d)/&#x2032;/g;

    $chunk =~ s/&lt;3(?!\d)([^<>]*?)/\ &#x0361;$1/gs;
    $chunk =~ s/([^<>]*?)&gt;3(?!\d)/\ &#x0361;$1/gs;

    $chunk =~ s/&lt;4(?!\d)([^<>]*?)/\ &#x035C;$1/gs;
    $chunk =~ s/([^<>]*?)&gt;4(?!\d)/\ &#x035C;$1/gs;

    $chunk =~ s/&lt;5(?!\d)([^<>]*?)/\ &#x035D;$1/gs;
    $chunk =~ s/([^<>]*?)&gt;5(?!\d)/\ &#x035D;$1/gs;

    $chunk =~ s/&lt;1[69](?!\d)/&#x2035;/g;
    $chunk =~ s/&gt;1[69](?!\d)/&#x2032;/g;


    if ($debug) {
        print STDERR "Unmatched markup: $1\n$chunk\n\n" if $chunk =~ m/((?:&lt;|&gt;)\d*)/;
    }
    else {
        # Tidy up unbalanced <> markup
        $chunk =~ s#&lt;\d*#&lt;#g;
        $chunk =~ s#&gt;\d*#&gt;#g;
    }

    # Quotation marks: it's not necessary to escape " in XML text nodes.

    $chunk =~ s/\"1/&#x201E;/g;
    $chunk =~ s/\"2/&#x201C;/g;

    $chunk =~ s/(&amp|[\@\^\$\d\s\n~])\"3\"3/$1&#x201c;/g;
    $chunk =~ s/(&amp;|[\@\^\$\d\s\n~])\"3/$1&#x2018;/g;
    $chunk =~ s/\"3\"3/&#x201d;/g;
    $chunk =~ s/\"3/&#x2019;/g;

    $chunk =~ s/\"4/&#x201A;/g;
    $chunk =~ s/\"5/&#x201B;/g;

    $chunk =~ s/(&amp;|[\@\^\$\d\s\n~])\"6/$1&#x00AB;/g;
    $chunk =~ s/\"6/&#x00BB;/g;

    $chunk =~ s/(&amp;|[\@\^\$\d\s\n~])\"7/$1&#x2039;/g;
    $chunk =~ s/\"7/&#x203A;/g;

    $chunk =~ s/(&amp;|[\x01-\x1f\@\^@\$\d\s\n~])\"\d+/$1&#x201C;/g;
    $chunk =~ s/\"\d+/&#x201D;/g;

    # [] (brackets, etc.)

    $chunk =~ s#\[(\d+)#if(exists $Diogenes::BetaHtml::bra{$1})
              {$Diogenes::BetaHtml::bra{$1}} else
              {print STDERR "Missing [: $1\n";"[$1??"}#ge;
    $chunk =~ s#\](\d+)#if(exists $Diogenes::BetaHtml::ket{$1})
              {$Diogenes::BetaHtml::ket{$1}} else
              {print STDERR "Missing ]: $1\n";"]$1??"}#ge;

    print STDERR "Unmatched markup: $1\n$chunk\n\n" if $chunk =~ m/([\]\[]\d+)/;

    # Some extra markup related to brackets.
    $chunk =~ s#\[?\.\.\.+\]?#<gap/>#g;
    $chunk =~ s#\[([^\]\n])\]#<del>$1</del>#g;

    $chunk =~ s#&lt;\.\.\.+&gt;#<supplied><gap/></supplied>#g;
    $chunk =~ s#&lt;([^.&><]*)\.\.\.+&gt;#<supplied>$1<gap/></supplied>#g;
    $chunk =~ s#&lt;\.\.\.+([^.&><]*)&gt;#<supplied><gap/>$1</supplied>#g;

    $chunk =~ s#&lt;([^&<>]*)&gt;#<supplied>$1</supplied>#g;

    # % special characters

    $chunk =~ s#%(\d+)#if(exists $Diogenes::BetaHtml::percent{$1})
                       {$Diogenes::BetaHtml::percent{$1}} else
                       {print STDERR "Missing %: $1\n";"%$1??"}#ge;
    $chunk =~ s/%/&#x2020;/g;


    # # and *# special chars

    $chunk =~ s/\*#(\d+)/if(exists $Diogenes::BetaHtml::starhash{$1})
                             {$Diogenes::BetaHtml::starhash{$1}} else
                             {print STDERR "Missing *#: $1\n";"*#$1??"}/ge;
    $chunk =~ s/(?<!&)#(\d+)/if(exists $Diogenes::BetaHtml::hash{$1})
                             {$Diogenes::BetaHtml::hash{$1}} else
                             {print STDERR "Missing #: $1\n";"#$1??"}/ge;
    $chunk =~ s/(?<!&)#/&#x0374;/g;

    # Some further punctuation
    $chunk =~ s/_/\ -\ /g;
    $chunk =~ s/!/./g;


    # Whitespace  FIXME: do all numbered items properly

    # Line/page breaks
    $chunk =~ s#\@1(?!\d)#<pb/>#g;
    $chunk =~ s#\@6(?!\d)#<lb/>#g;
    $chunk =~ s#\@9(?!\d)#<gap/>#g;

    ## Sometimes these appear at the end of a line, to no apparent purpose.
    # $chunk =~ s#@+\s*$##g;
    # $chunk =~ s#@\d+\s*$##g;
    # $chunk =~ s#@+\s*\n#\n#g;
    # $chunk =~ s#@\d+\s*\n#\n#g;

    if ($opt_a) {
        $chunk =~ s#@@+\d*#    #g;
        $chunk =~ s#@\d+#  #g;
        $chunk =~ s#@# #g;
        $chunk =~ s#\^(\d+)#' ' x ($1/4)#ge;
        $chunk =~ s#\^# #ge;
    } else {
        $chunk =~ s#(@@+)(?!\d)#q{<space quantity="}.(length $1).q{"/>}#ge;
        $chunk =~ s#@(?!\d)#<space/>#g;
        $chunk =~ s#\^(\d+)#q{<space quantity="}.($1/4).q{"/>}#ge;
        $chunk =~ s#\^#<space quantity="0.25"/>#g;
        $chunk =~ s#@(\d*)##g;
    }

    # Remove end-of-digit escapes
    $chunk =~ s#\`##g;

    return $chunk;
}

sub write_xml_file {
    my ($file, $text) = @_;

    if ($debug) {
        my $tmpfile = File::Spec->catfile( $path, $file) . '.tmp';
        open( OUT, ">:encoding(UTF-8)", "$tmpfile" ) or die $!;
        print OUT $text;
        close(OUT) or die $!;
    }

    my $xmldoc = post_process_xml($text, $file);

    if ($opt_p) {
        $xmldoc = milestones($xmldoc);
    }

    if ($libxml) {
        # At this point, the text is a mixture of utf8 (Greek) and hex
        # entities for more obscure punctuation, etc.  Unfortunately,
        # the serialisation function for libxml insists on flattening
        # all the entities out to utf8 (the alternative is to output
        # ascii with everything as entities).  When using
        # XML::DOM::Lite, the -e flag can be used to suppress the
        # flattening of hex entities to utf8.
        $text = $xmldoc->documentElement->toString;
    }
    else {
        my $serializer = XML::DOM::Lite::Serializer->new(indent=>'none');
        $text = $serializer->serializeToString($xmldoc);
    }

    $text = ad_hoc_fixes($text, $file);

    my $file_path = File::Spec->catfile( $path, $file );
    if ($opt_l) {
        open(LINT, "|xmllint --format - >$file_path") or die "Can't open xmllint: $!";
        print LINT $text;
        close(LINT) or die "Could not close xmllint!\n";
    }
    else {
        open( OUT, ">:encoding(UTF-8)", "$file_path" ) or die "Could not create $file\n";
        print OUT $text;
        close(OUT) or die "Could not close $file\n";
    }
    print AUTHTAB "  </work>\n";

    if ($opt_s) {
        print "    Validating $file ... ";
        die "Error: Java is required for validation, but java not found"
            unless which 'java';
        # xmllint validation errors can be misleading; jing is better
        # my $ret = `xmllint --noout --relaxng digiliblt.rng $file_path`;
        # my $ret = `java -jar jing.jar -c digiliblt.rnc $file_path`;
        my $ret = `java -jar jing.jar -c tei_all.rnc $file_path`;
        if ($ret) {
            print "Invalid.\n";
            print $ret;
        }
        else {
            print "Valid.\n";
        }
    }
}

sub post_process_xml {
    my $in = shift;
    my $file = shift;

    my ($parser, $xmldoc);
    if ($libxml) {
        $parser = XML::LibXML->new({huge=>1});
        $xmldoc = $parser->parse_string($in);
    }
    else {
        $parser = XML::DOM::Lite::Parser->new();
        $xmldoc = $parser->parse($in);
    }

    # Change 'space' elements to 'rend' attributes.  We do this first,
    # and then again at the end, to take into account changes in
    # between.
    fixup_spaces($xmldoc);

##### do this here?
#     $chunk =~
#         s#(<hi rend[^>]+>)(.*)<head>(.*)</hi>(.*)</head>#$1$2<head>$3</head>$4</hi>#gs;
#         s#(<hi rend.*?)(<head>.*?)</hi>(.*)</head>#$1$2</head>$3</hi>#gs;
#     $chunk =~
#         s#<head>(.*)(<hi rend[^>]+>)(.*)</head>(.*)</hi>#<head>$1$2$3</hi>$4</head>#gs;
#         s#(<head>.*?)(<hi .*?)</head>(.*?)</hi>#$1foo$2</hi>$3</head>#gs;
#      $chunk =~
#          s#(<hi rend.*?)(<head>.*?)</hi>(.*)</head>#$1$2</head>$3</hi>#gs;



    # FIXME: and we should remove any 'div's or 'l's inside, though
    # preserving their content.

    # Remove all div and l elements with n="t", preserving content;
    # these are just titles and usually have a 'head' inside, so
    # should not appear in a separate div or line.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('l'),
                          $xmldoc->getElementsByTagName('div'),) {
            my $n = $node->getAttribute('n');
            if ($n and $n =~ m/^t\d?$/) {
                # In most cases, the node has a 'head' or 'label', which
                # can be promoted.
                my $has_head = 0;
                foreach ($node->childNodes) {
                    $has_head++ if $_->nodeName =~ m/^head|label$/;
                }
                if ($has_head) {
                    foreach my $child ($node->childNodes) {
                        $node->parentNode->insertBefore( $child, $node );
                    }
                    $node->unbindNode;
                }
                elsif ($node->nodeName eq 'l') {
                    # In those rare cases where there is just plain text
                    # within an 'l', we wrap it in a label instead.
                    $node->removeAttribute('n');
                    $node->setNodeName('label');
                }
            }
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('div') },
                          @{ $xmldoc->getElementsByTagName('l') }) {
            my $n = $node->getAttribute('n');
            if ($n and $n =~ m/^t\d?$/) {
                # In most cases, the node has a 'head' or 'label', which
                # can be promoted.
                my $has_head = 0;
                foreach (@{ $node->childNodes }) {
                    $has_head++ if $_->nodeName =~ m/^head|label$/;
                }
                if ($has_head) {
                    # We need a copy of the list, or the children die when
                    # the parent is removed.
                    my @nodelist = @{ $node->childNodes };
                    foreach my $child (@nodelist) {
                        $node->parentNode->insertBefore( $child, $node );
                    }
                    $node->unbindNode;
                }
                elsif ($node->nodeName eq 'l') {
                    # In those rare cases where there is just plain
                    # text within an 'l', we wrap it in a label instead.
                    $node->removeAttribute('n');
                    $node->nodeName('label');
                }
            }
        }
    }

    # FIXME When the 'head' is the first non-blank child of the 'p' or
    # 'l' we move the 'head' to just before its parent, and then
    # delete the former parent if it has only whitespace content.  But
    # we must not do that elsewhere, for in texts with 'div's that do
    # not respect text structure -- such as Stephanus pages -- a heading
    # can appear anywhere.

    # A 'head' often appears inside 'p' or 'l', which isn't valid.  So
    # we move the 'head' to just before its parent, and then delete
    # the former parent if it has only whitespace content.

    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('head')) {
            my $parent = $node->parentNode;
            if ($parent->nodeName eq 'l' or $parent->nodeName eq 'p') {
                $parent->parentNode->insertBefore($node, $parent);
                $parent->unbindNode unless $parent->textContent =~ m/\S/;
            }
        }
    }
    else {
        my $nodelist = $xmldoc->getElementsByTagName('head');
        foreach my $node (@{ $nodelist }) {
            my $parent = $node->parentNode;
            if ($parent->nodeName eq 'l' or $parent->nodeName eq 'p') {
                $parent->parentNode->insertBefore($node, $parent);
                unless ($parent->textContent =~ m/\S/) {
                    $parent->unbindNode;
                }
            }
        }
    }

    # FIXME: not always true.  Do this only when the two <head>s are together in a <div n="t"> or <l n="t1"><l n="t2"> situation.

    # When there are two 'head's in immediate succession, it's usually
    # just a line break, so we unify them.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('head')) {
            my $sib = $node->nextNonBlankSibling;
            if ($sib and $sib->nodeName eq 'head') {
                $node->appendText(' ');
                $node->appendChild($_) foreach $sib->childNodes;
                $sib->unbindNode;
            }
        }
    }
    else {
        my $nodelist = $xmldoc->getElementsByTagName('head');
        foreach my $node (@{ $nodelist }) {
            if ($node) {
                my $sib = $node->nextNonBlankSibling;
                if ($sib and $sib->nodeName eq 'head') {
                    $node->appendChild($xmldoc->createTextNode(' '));
                    # childNodes returns a reference to a live list which
                    # appendChild modifies, so we cannot iterate over it
                    # reliably without copying its contents first.
                    my @nodelist2 = @{ $sib->childNodes };
                    foreach my $n (@nodelist2) {
                        $node->appendChild($n);
                    }
                    # We have to remove nodes from the gEBTN list
                    # manually; unlike the one returned by
                    # childNodes(), it is not live and does not update
                    # automatically.
                    $nodelist->removeNode($sib);
                    $sib->unbindNode;
                }
            }
        }
    }

    # FIXME: remove this

    # Any remaining 'space' within a 'head' is just superfluous
    # indentation left over from the unification of a multi-line set
    # of 'head's, so should just be removed.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('head')) {
            foreach my $child ($node->childNodes) {
                if ($child->nodeName eq 'space') {
                    $child->unbindNode;
                }
            }
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('head') }) {
            foreach my $child (@{ $node->childNodes }) {
                if ($child->nodeName eq 'space') {
                    $child->unbindNode;
                }
            }
        }
    }

    # Some texts have multiple 'head's spread throughout a single
    # 'div' or 'body', such as when these represent the titles of
    # works to which a list of fragments have been assigned.  When
    # this happens, we change the 'head's to 'label's, of which we are
    # allowed to have more than one.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('head')) {
            my $parent = $node->parentNode;
            foreach my $sibling ($parent->childNodes) {
                if (not $node->isSameNode($sibling) and $sibling->nodeName eq 'head') {
                    $sibling->setNodeName('label');
                }
            }
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('head') }) {
            my $parent = $node->parentNode;
            foreach my $sibling (@{ $parent->childNodes }) {
                if ($node ne $sibling and $sibling->nodeName eq 'head') {
                    $sibling->nodeName('label');
                }
            }
        }
    }

    # There may still be solitary 'head's that are not first item in
    # the 'div', so change 'head's preceded by 'p' or 'l' to 'label's.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('head')) {
            my $sib = $node->previousSibling;
            while ($sib) {
                if ($sib->nodeName eq 'l' or $sib->nodeName eq 'p' or $sib->nodeName eq 'label') {
                    $node->setNodeName('label');
                    last;
                }
                $sib = $sib->previousSibling;
            }
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('head') }) {
            my $sib = $node->previousSibling;
            while ($sib) {
                if ($sib->nodeName eq 'l' or $sib->nodeName eq 'p' or $sib->nodeName eq 'label') {
                    $node->nodeName('label');
                    last;
                }
                $sib = $sib->previousSibling;
            }
        }
    }

    # Some texts have an EXPLICIT within a 'label', which generally fall
    # after the end of the 'div', so we tuck them into the end of the
    # preceding 'div'.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('label')) {
            if ($node->textContent =~ m/EXPLICIT/) {
                $node->setNodeName('trailer');
                my $sib = $node;
                while ($sib = $sib->previousSibling) {
                    if ($sib->nodeName eq 'div') {
                        $sib->appendChild($node);
                        last;
                    }
                }
            }
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('label') }) {
            if ($node->textContent =~ m/EXPLICIT/) {
                $node->nodeName('trailer');
                my $sib = $node;
                while ($sib = $sib->previousSibling) {
                    if ($sib->nodeName eq 'div') {
                        $sib->appendChild($node);
                        last;
                    }
                }
            }
        }
    }

    # BetaHtml.pm uses 'i', 'super' and 'small', so we need to change
    # those into TEI-compatible markup.
    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('i')) {
            $node->setNodeName('hi');
            $node->setAttribute('rend', 'italic');
        }
        foreach my $node ($xmldoc->getElementsByTagName('super')) {
            $node->setNodeName('hi');
            $node->setAttribute('rend', 'superscript');
        }
        foreach my $node ($xmldoc->getElementsByTagName('small')) {
            $node->setNodeName('hi');
            $node->setAttribute('rend', 'small');
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('i') }) {
            $node->nodeName('hi');
            $node->setAttribute('rend', 'italic');
        }
        foreach my $node (@{ $xmldoc->getElementsByTagName('super') }) {
            $node->nodeName('hi');
            $node->setAttribute('rend', 'superscript');
        }
        foreach my $node (@{ $xmldoc->getElementsByTagName('small') }) {
            $node->nodeName('hi');
            $node->setAttribute('rend', 'small');
        }
    }

    # Some texts are nothing but titles in a 'head', so we provide an empty div.
    if ($libxml) {
        my $body = $xmldoc->getElementsByTagName('body')->[0];
        my $has_content = 0;
        foreach ($body->childNodes) {
            $has_content++ if $_->nodeType != XML_TEXT_NODE() and $_->nodeName ne 'head';
        }
        if (not $has_content) {
            $body->appendChild($xmldoc->createElement('div'));
        }
    }
    else {
        my $body = $xmldoc->getElementsByTagName('body')->[0];
        my $has_content = 0;
        foreach (@{ $body->childNodes }) {
            $has_content++ if $_->nodeType != TEXT_NODE() and $_->nodeName ne 'head';
        }
        if (not $has_content) {
            $body->appendChild($xmldoc->createElement('div'));
        }
    }

    fixup_spaces($xmldoc);

    unless ($libxml or $opt_e) {
        # libxml2 normalizes all output to utf8, including
        # entities. In order to produce the same output with
        # XML::DOM::Lite, we need to do the same.
        convert_entities($xmldoc);
    }

    return $xmldoc;
}

sub convert_entities {
    my $node = shift;
    foreach my $n (@{ $node->childNodes }) {
        if ($n->nodeType == TEXT_NODE()) {
            my $val = $n->nodeValue;
            $val =~ s/&#x([0-9a-fA-F]+);/hex_to_utf8($1)/ge;
            $n->nodeValue($val);
        }
        else {
             convert_entities($n);
        }
    }
}

sub hex_to_utf8 {
    my $hex = shift;
    # Protect against accidentally re-introducing unescaped XML markup
    if ($hex =~ m/^0*26$/) {
        return '&amp;';
    }
    elsif ($hex =~ m/^0*3c$/i) {
        return '&lt;';
    }
    elsif ($hex =~ m/^0*3e$/i) {
        return '&gt;';
    }
    else {
        return chr(hex($hex));
    }
}

sub fixup_spaces {
    my $xmldoc = shift;
    # Change 'space' to indentation at start of para, line, etc.  Note
    # that this is an imperfect heuristic.  A 'space' at the start of
    # a line of verse from a fragmentary papyrus is probably correct,
    # and really should not be converted to indentation.

    if ($libxml) {
        foreach my $node ($xmldoc->getElementsByTagName('space')) {
            my $next = $node->nextSibling;
            while ($next and $next->nodeType == XML_TEXT_NODE() and $next->data =~ m/^\s*$/s) {
                $next = $next->nextSibling;
            }
            my $parent = $node->parentNode;
            my $quantity = $node->getAttribute('quantity') || '1';
            # If 'space' comes right before (allowing whitespace).
            if ($next and $next->nodeName =~ m/^l|p|head|label$/) {
                $next->setAttribute('rend',"indent($quantity)");
                $node->unbindNode;
            } # If 'space' comes right after (allowing whitespace).
            elsif ($parent and $parent->nodeName =~ m/^l|p|head|label$/) {
                my $child = $parent->firstChild;
                while ($child->nodeType == XML_TEXT_NODE() and $child->data =~ m/^\s*$/s) {
                    $child = $child->nextSibling;
                }
                if ($child and $child->isSameNode($node)) {
                    $parent->setAttribute('rend',"indent($quantity)");
                    $node->unbindNode;
                }
            }
        }
    }
    else {
        foreach my $node (@{ $xmldoc->getElementsByTagName('space')} ) {
            my $next = $node->nextSibling;
            while ($next and $next->nodeType == TEXT_NODE() and $next->nodeValue =~ m/^\s*$/s) {
                $next = $next->nextSibling;
            }
            my $parent = $node->parentNode;
            my $quantity = $node->getAttribute('quantity') || '1';
            # If 'space' comes right before (allowing whitespace).
            if ($next and $next->nodeName =~ m/^l|p|head|label$/) {
                $next->setAttribute('rend',"indent($quantity)");
                $node->unbindNode;
            } # If 'space' comes right after (allowing whitespace).
            elsif ($parent and $parent->nodeName =~ m/^l|p|head|label$/) {
                my $child = $parent->firstChild;
                while ($child and $child->nodeType == TEXT_NODE() and $child->nodeValue =~ m/^\s*$/s) {
                    $child = $child->nextSibling;
                }
                if ($child and $child eq $node) {
                    $parent->setAttribute('rend',"indent($quantity)");
                    $node->unbindNode;
                }
            }
        }
    }
}

sub milestones {
    die "Milestones not implemented yet with XML::DOM::Lite\n." unless $libxml;
    my $xmldoc = shift;

    # Added this at the request of DigiLibLT.  They prefer paragraph
    # divs to be converted into milestones, so that <div type="par"
    # n="1"> becomes <milestone unit="par" n="1"/> and the
    # higher-level div is contained in just one <p>, with inner <p>s
    # removed. Found this surprisingly tricky, so we do this step by step
    if (not $is_verse) {
        my $xpc = XML::LibXML::XPathContext->new;
        $xpc->registerNs('x', $xmlns);
        # Put a collection of multiple <div type="par">s inside a big
        # <p>
        foreach my $node (
            # Find nodes with a child of at least one <div type="par">
            $xpc->findnodes('//*[x:div/@type="par"]',$xmldoc)) {
            my $new_p = $xmldoc->createElementNS( $xmlns, 'p');

            $new_p->appendText("\n");
            foreach my $child ($node->nonBlankChildNodes) {
                $new_p->appendChild($child);
            }
            $new_p->appendText("\n");
            $node->appendChild($new_p);
        }

        # Remove all <p>s inside <div type="par">
        foreach my $node (
            $xpc->findnodes('//x:div[@type="par"]/x:p',$xmldoc)) {
            my $parent = $node->parentNode;
            foreach my $child ($node->nonBlankChildNodes) {
                $parent->appendChild($child);
            }
            $node->unbindNode;
        }
        # Change divs to milestones
        foreach my $node (
            $xpc->findnodes('//x:div[@type="par"]',$xmldoc)) {
            my $mile = $xmldoc->createElementNS($xmlns, 'milestone');
            $mile->setAttribute("unit", "par" );
            $mile->setAttribute("n", $node->getAttribute('n') );
            my $parent = $node->parentNode;
            $parent->appendText("\n");
            $parent->appendChild($mile);
            $parent->appendText("\n");
            foreach my $child ($node->nonBlankChildNodes) {
                $parent->appendChild($child);
            }
            $node->unbindNode;
        }
        # The foregoing can end up with <head>s inside the new <p>s.
        foreach my $node (
            $xpc->findnodes('//x:p//x:head',$xmldoc)) {
            my $grandparent = $node->parentNode->parentNode;
            $grandparent->insertBefore($node, $node->parentNode);
            #              print $grandparent->nodeName;
        }
    }
    return $xmldoc;
}

sub ad_hoc_fixes {
    # This is for fixing desperate special cases.
    my $out = shift;
    my $file = shift;

    # Calpurnius Siculus
    if ($file eq 'phi0830001.xml') {
        $out =~ s#\[(<label [^>]*>)#$1\[#g;
        $out =~ s#</label>\]#\]</label>#g;
    }

    # Arrianus
    if ($file eq 'tlg2650001.xml') {
        $out =~ s#\[<head>#<head>\[#g;
        $out =~ s#</head>\]#\]</head>#g;
    }

    # Hyginus Myth
    if ($file eq 'phi1263001.xml') {
        $out =~ s#<label ([^>]*)><supplied>QVI PIISSIMI FVERVNT\.</supplied></label>\s*<div ([^>]*)>#<div $2>\n<label $1><supplied>QVI PIISSIMI FVERVNT.</supplied></label>#;
    }
    # Porphyry on Horace
    if ($file =~ m/^phi1512/) {
        # Not all of the Sermones have this heading and this one for
        # poem 3 is in the middle of the scholia to poem 2.
        $out =~ s#(<head [^>]*>EGLOGA III</head>.*?</p>\n)#<div type="lemma" n="t">$1</div>#s;
        # Another bizzarely placed heading
        $out =~ s#<head [^>]*>\[DE SATVRA</head>\s*<div type="lemma" n="12a">#<div type="lemma" n="12a"><head>DE SATURA</head>#;
    }

    return $out;
}

sub is_work_verse {
    my ($auth_num, $work_num) = @_;

    # All documentary corpora (papyri and inscriptions) are "verse", because line breaks and line numbers are significant.
    return 1 if $corpus =~ m/^chr|ddp|ins$/;

    # Two lists of hard-coded exceptions to the heuristic (prose is 0,
    # verse is 1).  verse_auths applies to all works.
    my %verse_auths = (
        'tlg:0019' => 1,
        'tlg:0031' => 0,
        'tlg:0085' => 1,
        'tlg:0384' => 0,
        'tlg:0388' => 0,
        'tlg:0434' => 1,
        'tlg:0527' => 0,
        'tlg:0538' => 0,
        'tlg:0552' => 0,
        'tlg:0744' => 0,
        'tlg:1379' => 0,
        'tlg:1463' => 0,
        'tlg:1719' => 0,
        'tlg:1734' => 0,
        'tlg:1760' => 0,
        'tlg:2017' => 0,
        'tlg:2021' => 0,
        'tlg:2022' => 0,
        'tlg:2035' => 0,
        'tlg:2042' => 0,
        'tlg:2062' => 0,
        'tlg:2074' => 0,
        'tlg:2102' => 0,
        'tlg:2762' => 0,
        'tlg:2866' => 0,
        'tlg:3002' => 0,
        'tlg:3177' => 0,
        'tlg:4015' => 0,
        'tlg:4085' => 0,
        'tlg:4090' => 0,
        'tlg:4102' => 0,
        'tlg:4110' => 0,
        'tlg:4117' => 0,
        'tlg:4292' => 0,
        'tlg:4333' => 0,
        );
    my %verse_works = (
        'phi:0474:056' => 0,
        'phi:0474:059' => 0,
        'phi:0474:061' => 0,
        'phi:0474:063' => 0,
        'phi:0684:011' => 0,
        'phi:0684:015' => 0,
        'phi:0684:016' => 0,
        'phi:0684:017' => 0,
        'phi:1212:007' => 0,
        'tlg:0059:007' => 0,
        'tlg:0059:010' => 0,
        'tlg:0059:015' => 0,
        'tlg:0059:037' => 0,
        'tlg:0062:070' => 0,
        'tlg:0096:016' => 0,
        'tlg:0096:017' => 0,
        'tlg:0212:003' => 0,
        'tlg:0212:004' => 1,
        'tlg:0319:004' => 1,
        'tlg:1466:002' => 1,
        'tlg:2702:021' => 0,
        'tlg:2968:001' => 0,
        'tlg:3141:005' => 0,
        'tlg:4066:001' => 1,
        'tlg:4066:005' => 0,
        'tlg:4066:008' => 0,
        'tlg:5014:016' => 0,
        'tlg:5014:020' => 0,
        );
    my $key = $corpus . ':' . $auth_num;
    if (exists $verse_auths{$key}) {
        return $verse_auths{$key};
    }
    $key = $corpus . ':' . $auth_num . ':' . $work_num;
    if (exists $verse_works{$key}) {
        return $verse_works{$key};
    }

    # Heuristic to tell prose from verse: a work is verse if its
    # lowest level of markup is "verse" rather than "line", if the
    # author has an "Lyr." etc. in their name or if the ratio of
    # hyphens is very low.  Prose authors often wrote epigrams.
    my $bottom = $level_label{$corpus}{$auth_num}{$work_num}{0};
    return 1 if $bottom =~ m/verse/;
    return 1 if $auth_name =~ m/Lyr\.|Epic/;
    return 1 if $work_name =~ m/^Epigramma/;
    return 1 if $work_name =~ m/poetica/i;
    return 0 if $work_name =~ m/sententiae/i;

    my $start_block = $work_start_block{$corpus}{$query->{auth_num}}{$work_num};
    my $next = $work_num;
    $next++;
    my $end_block = $work_start_block{$corpus}{$query->{auth_num}}{$next} ||
        $start_block + 1;
    my $offset = $start_block << 13;
    my $length = ($end_block - $start_block + 1) << 13;
    my $work = substr $buf, $offset, $length;

    my $hyphens_counter = () = $work =~ m/\-[\x80-\xff]/g;
    return 1 if $hyphens_counter == 0;
    my $lines_counter   = () = $work =~ m/\s[\x80-\xff]/g;
    my $ratio = $lines_counter / $hyphens_counter;
#     print "$work_name: $lines_counter - $hyphens_counter = $ratio\n";
    return 1 if $ratio > 20;
    return 0;
}

sub strip_formatting{
    my $x = shift;
    $query->beta_formatting_to_ascii(\$x);

    # Just in case: remove illegal chars for use in TEI header
    $x =~ s#\&\d*##g;
    $x =~ s#\$\d*##g;
    $x =~ s#\<\d*##g;
    $x =~ s#\>\d*##g;
    $x =~ s#\`# #g;
    $x =~ s#[\x00-\x08\x0b\x0c\x0e-\x1f]##g;
    return $x;
}

sub numerically { $a <=> $b; }

# Copied from the Roman.pm module on CPAN
sub roman {
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    my $arg = shift;
    return $arg unless $arg =~ m/^\d+$/;
    return $arg if $arg < 0 or $arg > 4000;
    my ($x, $roman);
    foreach (@figure) {
        my($digit, $i, $v) = (int($arg / $_), @{$roman_digit{$_}});
        if (1 <= $digit and $digit <= 3) {
            $roman .= $i x $digit;
        } elsif ($digit == 4) {
            $roman .= "$i$v";
        } elsif ($digit == 5) {
            $roman .= $v;
        } elsif (6 <= $digit and $digit <= 8) {
            $roman .= $v . $i x ($digit - 5);
        } elsif ($digit == 9) {
            $roman .= "$i$x";
        }
        $arg -= $digit * $_;
        $x = $i;
    }
    return $roman ? lc $roman : $arg;
}
