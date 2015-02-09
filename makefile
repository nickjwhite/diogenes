# Building Perseus_Data requires several things to be in available:
#
# - Morpheus needs to be installed, and its Latin and Greek stem
#   libraries built; download and build it from the
#   https://github.com/PerseusDL/morpheus repository, and set the
#   location of the stem libraries in STEMLIB below.
#
# - The Lewis-Short and LSJ lexica from Perseus; get them from the
#   https://github.com/PerseusDL/lexica repository and set the
#   location of the repository in LEXICA below.
#
# - The PHI and TLG datasets; specify their locations in PHIDIR and
#   TLGDIR below.

PHIDIR = $(HOME)/phi
TLGDIR = $(HOME)/tlg_e
STEMLIB = $(HOME)/morpheus/stemlib
LEXICA = $(HOME)/lexica

DEPDIR = dependencies
PDIR = $(DEPDIR)/Perseus_Data
PBUILD = $(DEPDIR)/Perseus_Build

UNICODEVERSION = 7.0.0
UNICODESUM = bfa3da58ea982199829e1107ac5a9a544b83100470a2d0cc28fb50ec234cb840

all: diogenes-browser/perl/Diogenes/unicode-equivs.pl

$(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt:
	wget -O $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt
	printf '%s  %s\n' $(UNICODESUM) $@ | sha256sum -c

diogenes-browser/perl/Diogenes/unicode-equivs.pl: utils/make_unicode_compounds.pl $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	@echo 'Building unicode equivalents table'
	./utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@

$(PBUILD)/check_phi:
	mkdir -p $(PBUILD)
	sed 's:PREFIX:$(PHIDIR):g' < $(DEPDIR)/phisums | sha256sum -c
	touch $@

$(PBUILD)/check_tlg:
	mkdir -p $(PBUILD)
	sed 's:PREFIX:$(TLGDIR):g' < $(DEPDIR)/tlgsums | sha256sum -c
	touch $@

$(PBUILD)/lat.words: $(PBUILD)/check_phi utils/make_latin_wordlist.pl
	./utils/make_latin_wordlist.pl $(PHIDIR) > $@

$(PBUILD)/tlg.words: $(PBUILD)/check_tlg utils/make_greek_wordlist.pl
	./utils/make_greek_wordlist.pl $(TLGDIR) > $@

$(PBUILD)/lat.morph: $(PBUILD)/lat.words
	MORPHLIB=$(STEMLIB) cruncher -L < $(PBUILD)/lat.words > $@

$(PBUILD)/tlg.morph: $(PBUILD)/tlg.words
	MORPHLIB=$(STEMLIB) cruncher < $(PBUILD)/tlg.words > $@

$(PBUILD)/lewis-index.txt: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml utils/index_lewis.pl
	./utils/index_lewis.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

$(PBUILD)/lewis-index-head.txt: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml utils/index_lewis_head.pl
	./utils/index_lewis_head.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

$(PBUILD)/lewis-index-trans.txt: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml utils/index_lewis_trans.pl
	./utils/index_lewis_trans.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

clean:
	rm -f $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	rm -f diogenes-browser/perl/Diogenes/unicode-equivs.pl
	rm -f $(PBUILD)/check_phi $(PBUILD)/check_tlg
	rm -f $(PBUILD)/lat.words $(PBUILD)/tlg.words
	rm -f $(PBUILD)/lat.morph $(PBUILD)/tlg.morph
	rm -f $(PBUILD)/lewis-index.txt
	rm -f $(PBUILD)/lewis-index-head.txt
	rm -f $(PBUILD)/lewis-index-trans.txt
