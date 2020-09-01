#!/usr/bin/env perl
# Unfortunately Perseus updated the formatting of their XML files
# to be more usable, which broke our naive XML parsing. This script
# returns the XML to its less readable form, as that is easier than
# converting all of Diogenes to do proper XML parsing.

use strict;
use warnings;
# Input layer needs to be raw, not utf8.
binmode STDOUT, ':utf8';

# Turn off external DTDs in case TEI website is down.
use XML::LibXML::Reader;
my $reader = XML::LibXML::Reader->new(IO => \*STDIN,
                                      load_ext_dtd => 0);

my $at_start = 1;
my $in_entry = 0;
my $in_whitespace = 0;

while ($reader->read) {
  processNode($reader);
}

sub processNode {
    if ($reader->nodeType == XML_READER_TYPE_ELEMENT) {
        my $name = $reader->name;
        my $closer = $reader->isEmptyElement ? ' />' : '>';
        if ($name eq 'entryFree') {
            $in_entry = 1;
            print "\n" unless $at_start;
            $at_start = 0;
        }
        if ($in_entry) {
            print "<$name";
            if ($reader->hasAttributes) {
                while ($reader->moveToNextAttribute) {
                    my $attr_name = $reader->name;
                    my $attr_val = $reader->value;
                    # The TEIform attribs take up a vast amount of space.
                    next if $attr_name eq 'TEIform';
                    print ' ' . $attr_name . '="' . $attr_val . '"';
                }
                print $closer;

            }
            else {
                print $closer;
            }
        }
        $in_whitespace = 0;
    }
    elsif ($reader->nodeType == XML_READER_TYPE_END_ELEMENT and $in_entry) {
        my $name = $reader->name;
        print "</$name>";
        if ($name eq 'entryFree') {
            $in_entry = 0;
        }
        $in_whitespace = 0;
    }
    elsif ($reader->nodeType == XML_READER_TYPE_TEXT and $in_entry) {
        my $text = $reader->value;
        print xml_escape($text);
        $in_whitespace = 0;
    }
    elsif ($reader->nodeType == XML_READER_TYPE_SIGNIFICANT_WHITESPACE
           and $in_entry) {
        print ' ' unless $in_whitespace;
        $in_whitespace = 1;
    }
}

# I could not find out how to turn off resolving predefined XML entities in any parser that was functional enough to resolve external entities.
sub xml_escape {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}
