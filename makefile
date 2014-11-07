UNICODEVERSION = 7.0.0

all: diogenes-browser/perl/Diogenes/unicode-equivs.pl

UnicodeData-$(UNICODEVERSION).txt:
	wget -O $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt

diogenes-browser/perl/Diogenes/unicode-equivs.pl: diogenes-browser/perl/Diogenes/make_unicode_compounds.pl UnicodeData-$(UNICODEVERSION).txt
	@echo 'Building unicode equivalents table'
	perl diogenes-browser/perl/Diogenes/make_unicode_compounds.pl < UnicodeData-$(UNICODEVERSION).txt > $@
