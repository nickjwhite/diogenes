# Building Perseus_Data requires morpheus to be installed; get it
# from the https://github.com/PerseusDL/morpheus repository, build
# the latin stems, and and set the location of the stem library in
# STEMLIB below.
#
# It also requires the Lewis Short and LSJ lexica from Perseus; get
# them from the https://github.com/PerseusDL/lexica repository and
# set the location of the repository in LEXICA below.
#
# It also requires the PHI and TLG datasets; specify their
# locations in PHIDIR and TLGDIR below.

PHIDIR = $(HOME)/phi
TLGDIR = $(HOME)/tlg_e
STEMLIB = $(HOME)/morpheus/stemlib
LEXICA = $(HOME)/lexica

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
	./utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@

$(PDIR)/check_phi:
	sed 's:PREFIX:$(PHIDIR):g' < $(DEPDIR)/phisums | sha256sum -c
	touch $@

$(PDIR)/check_tlg:
	sed 's:PREFIX:$(TLGDIR):g' < $(DEPDIR)/tlgsums | sha256sum -c
	touch $@

$(PDIR)/lat.words: $(PDIR)/check_phi utils/make_latin_wordlist.pl
	mkdir -p $(PDIR)
	./utils/make_latin_wordlist.pl $(PHIDIR) > $@

$(PDIR)/tlg.words: $(PDIR)/check_tlg utils/make_greek_wordlist.pl
	mkdir -p $(PDIR)
	./utils/make_greek_wordlist.pl $(TLGDIR) > $@

$(PDIR)/lat.morph: $(PDIR)/lat.words
	MORPHLIB=$(STEMLIB) cruncher -L < $(PDIR)/lat.words > $@

$(PDIR)/tlg.morph: $(PDIR)/tlg.words
	MORPHLIB=$(STEMLIB) cruncher < $(PDIR)/tlg.words > $@

$(PDIR)/lewis-index.txt: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml utils/index_lewis.pl
	./utils/index_lewis.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

$(PDIR)/lewis-index-head.txt: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml utils/index_lewis_head.pl
	./utils/index_lewis_head.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

$(PDIR)/lewis-index-trans.txt: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml utils/index_lewis_trans.pl
	./utils/index_lewis_trans.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

clean:
	rm -f $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	rm -f diogenes-browser/perl/Diogenes/unicode-equivs.pl
	rm -f $(PDIR)/check_phi $(PDIR)/check_tlg
	rm -f $(PDIR)/lat.words $(PDIR)/tlg.words
	rm -f $(PDIR)/lat.morph $(PDIR)/tlg.morph
	rm -f $(PDIR)/lewis-index.txt
	rm -f $(PDIR)/lewis-index-head.txt
	rm -f $(PDIR)/lewis-index-trans.txt
