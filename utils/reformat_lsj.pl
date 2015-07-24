#!/usr/bin/perl -w
# Unfortunately Perseus updated the formatting of their XML files
# to be more usable, which broke our naive XML parsing. This script
# returns the XML to its less readable form, as that is easier than
# converting all of Diogenes to do proper XML parsing.

use strict;

# use local CPAN
use FindBin qw($Bin);
use File::Spec::Functions qw(catdir);
use lib (catdir($Bin, '..', 'dependencies', 'CPAN') );

use XML::Tiny qw(parsefile);

sub attribs_str {
	my $s = '';
	for my $attrib (@_) {
		for my $key (sort(keys(%$attrib))) {
			$s .= ' ' . $key . '="' . $attrib->{$key} . '"';
		}
	}
	return $s;
}

my $inentry = 0;
sub print_contents {
	for my $item (@_) {
		if(ref($item) eq 'ARRAY') {
			print_contents(@$item);
			next;
		}

		if($item->{'type'} eq 't') {
			printf("%s", $item->{'content'});
		} else {
			if($item->{'name'} eq 'entryFree') {
				$inentry = 1;
			}
			printf("<%s %s>", $item->{'name'}, attribs_str($item->{'attrib'}));
			print_contents($item->{'content'});
			printf("</%s>", $item->{'name'});
			if(! $inentry or $item->{'name'} eq 'entryFree') {
				printf("\n");
			}
			if($item->{'name'} eq 'entryFree') {
				$inentry = 0;
			}
		}
	}
}

my @x = parsefile(\*STDIN, no_entity_parsing => 1);

for my $i (@x) {
	print_contents($i);
}

printf("\n");
