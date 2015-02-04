DEPDIR = dependencies

UNICODEVERSION = 7.0.0
UNICODESUM = bfa3da58ea982199829e1107ac5a9a544b83100470a2d0cc28fb50ec234cb840

all: diogenes-browser/perl/Diogenes/unicode-equivs.pl

$(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt:
	wget -O $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt
	printf '%s  %s\n' $(UNICODESUM) $@ | sha256sum -c

diogenes-browser/perl/Diogenes/unicode-equivs.pl: utils/make_unicode_compounds.pl $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	@echo 'Building unicode equivalents table'
	perl utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@
