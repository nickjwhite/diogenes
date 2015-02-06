# Note: Perseus_Data building requires morpheus to be installed;
#       get it from https://github.com/PerseusDL/morpheus
#       build the latin stems, and and set the location of that
#       stem library in STEMLIB below.
#       It also requires the PHI and TLG datasets; specify their
#       locations in PHIDIR and TLGDIR below.

PHIDIR = $(HOME)/phi
TLGDIR = $(HOME)/tlg_e
STEMLIB = $(HOME)/morpheus/stemlib

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

$(PDIR)/check_phi:
	sed 's:PREFIX:$(PHIDIR):g' < $(DEPDIR)/phisums | sha256sum -c
	touch $@

$(PDIR)/check_tlg:
	sed 's:PREFIX:$(TLGDIR):g' < $(DEPDIR)/tlgsums | sha256sum -c
	touch $@

$(PDIR)/lat.words: $(PDIR)/check_phi utils/make_latin_wordlist.pl
	mkdir -p $(PDIR)
	utils/make_latin_wordlist.pl $(PHIDIR) > $@

$(PDIR)/tlg.words: $(PDIR)/check_tlg utils/make_greek_wordlist.pl
	mkdir -p $(PDIR)
	utils/make_greek_wordlist.pl $(TLGDIR) > $@

$(PDIR)/lat.morph: $(PDIR)/lat.words
	MORPHLIB=$(STEMLIB) cruncher -L < $(PDIR)/lat.words > $@

$(PDIR)/tlg.morph: $(PDIR)/tlg.words
	MORPHLIB=$(STEMLIB) cruncher < $(PDIR)/tlg.words > $@

clean:
	rm -f $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	rm -f diogenes-browser/perl/Diogenes/unicode-equivs.pl
	rm -f $(PDIR)/check_phi $(PDIR)/check_tlg
	rm -f $(PDIR)/lat.words $(PDIR)/tlg.words
	rm -f $(PDIR)/lat.morph $(PDIR)/tlg.morph
