PHIDIR = $(HOME)/phi
TLGDIR = $(HOME)/tlg_e

DEPDIR = dependencies
PDIR = $(DEPDIR)/Perseus_Data

UNICODEVERSION = 7.0.0
UNICODESUM = bfa3da58ea982199829e1107ac5a9a544b83100470a2d0cc28fb50ec234cb840

all: diogenes-browser/perl/Diogenes/unicode-equivs.pl

$(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt:
	wget -O $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt
	printf '%s  %s\n' $(UNICODESUM) $@ | sha256sum -c

diogenes-browser/perl/Diogenes/unicode-equivs.pl: utils/make_unicode_compounds.pl $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	@echo 'Building unicode equivalents table'
	perl utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@

check_phi:
	sed 's:PREFIX:$(PHIDIR):g' < $(DEPDIR)/phisums | sha256sum -c

check_tlg:
	sed 's:PREFIX:$(TLGDIR):g' < $(DEPDIR)/tlgsums | sha256sum -c

$(PDIR)/lat.words: check_phi utils/make_latin_wordlist.pl
	mkdir -p $(PDIR)
	utils/make_latin_wordlist.pl $(PHIDIR) > $@

$(PDIR)/tlg.words: check_tlg utils/make_greek_wordlist.pl
	mkdir -p $(PDIR)
	utils/make_greek_wordlist.pl $(TLGDIR) > $@
