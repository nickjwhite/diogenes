# Building Perseus_Data requires several things to be in available:
#
# - Morpheus needs to be installed, and its Latin and Greek stem
#   libraries built; download and build it from the
#   https://github.com/PerseusDL/morpheus repository, and set the
#   location of the stem libraries in STEMLIB below.
#
# - The Lewis-Short lexicon from Perseus; get it from the
#   https://github.com/PerseusDL/lexica repository and set the
#   location of the repository in LEXICA below.
#
# - The LSJ lexicon; get it from https://njw.name/1999.04.0057.xml.xz
#   and set its location in LSJDIR below.
#
# - The PHI and TLG datasets; specify their locations in PHIDIR and
#   TLGDIR below.
#
# - The gcide dictionary (dict-gcide on debian), specify its location
#   in GCIDE below.

PHIDIR = $(HOME)/phi
TLGDIR = $(HOME)/tlg_e
STEMLIB = $(HOME)/morpheus/stemlib
LEXICA = $(HOME)/lexica
LSJDIR = $(HOME)
GCIDE = /usr/share/dictd/gcide.dict.dz

DEPDIR = dependencies
PDIR = $(DEPDIR)/Perseus_Data
PBUILD = $(DEPDIR)/Perseus_Build

UNICODEVERSION = 7.0.0
UNICODESUM = bfa3da58ea982199829e1107ac5a9a544b83100470a2d0cc28fb50ec234cb840

DATAFILES = \
	$(PDIR)/lat.ls.perseus-eng1.xml \
	$(PDIR)/grc.lsj.perseus-eng0.xml \
	$(PDIR)/latin-analyses.txt \
	$(PDIR)/greek-analyses.txt \
	$(PDIR)/latin-analyses.idt \
	$(PDIR)/greek-analyses.idt \
	$(PDIR)/latin-lemmata.txt \
	$(PDIR)/greek-lemmata.txt \
	$(PDIR)/gcide.txt

.SUFFIXES: .txt .idt

all: diogenes-browser/perl/Diogenes/unicode-equivs.pl

Perseus_Data: $(DATAFILES)

$(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt:
	wget -O $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt
	printf '%s  %s\n' $(UNICODESUM) $@ | sha256sum -c

diogenes-browser/perl/Diogenes/unicode-equivs.pl: utils/make_unicode_compounds.pl $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	@echo 'Building unicode equivalents table'
	./utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@

$(PBUILD)/check_phi: $(DEPDIR)/phisums
	mkdir -p $(PBUILD)
	sed 's:PREFIX:$(PHIDIR):g' < $(DEPDIR)/phisums | sha256sum -c
	touch $@

$(PBUILD)/check_tlg: $(DEPDIR)/tlgsums
	mkdir -p $(PBUILD)
	sed 's:PREFIX:$(TLGDIR):g' < $(DEPDIR)/tlgsums | sha256sum -c
	touch $@

$(PBUILD)/lat.words: utils/make_latin_wordlist.pl $(PBUILD)/check_phi
	./utils/make_latin_wordlist.pl $(PHIDIR) > $@

$(PBUILD)/tlg.words: utils/make_greek_wordlist.pl $(PBUILD)/check_tlg
	./utils/make_greek_wordlist.pl $(TLGDIR) > $@

$(PBUILD)/lat.morph: $(PBUILD)/lat.words
	MORPHLIB=$(STEMLIB) cruncher -L < $(PBUILD)/lat.words > $@

$(PBUILD)/tlg.morph: $(PBUILD)/tlg.words
	MORPHLIB=$(STEMLIB) cruncher < $(PBUILD)/tlg.words > $@

$(PBUILD)/lewis-index.txt: utils/index_lewis.pl $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml
	./utils/index_lewis.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

$(PBUILD)/lewis-index-head.txt: utils/index_lewis_head.pl $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml
	./utils/index_lewis_head.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

$(PBUILD)/lewis-index-trans.txt: utils/index_lewis_trans.pl $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml
	./utils/index_lewis_trans.pl < $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml > $@

# It would be nice to use LSJ from lexica repo, but our tools don't
# yet handle the new format it uses
$(PDIR)/grc.lsj.perseus-eng0.xml: $(LSJDIR)/1999.04.0057.xml.xz
	xzcat < $(LSJDIR)/1999.04.0057.xml.xz > $@

$(PBUILD)/lsj-index.txt: utils/index_lsj.pl $(PDIR)/grc.lsj.perseus-eng0.xml
	./utils/index_lsj.pl < $(PDIR)/grc.lsj.perseus-eng0.xml > $@

$(PBUILD)/lsj-index-head.txt: utils/index_lsj_head.pl $(PDIR)/grc.lsj.perseus-eng0.xml
	./utils/index_lsj_head.pl < $(PDIR)/grc.lsj.perseus-eng0.xml > $@

$(PBUILD)/lsj-index-trans.txt: utils/index_lsj_trans.pl $(PDIR)/grc.lsj.perseus-eng0.xml
	./utils/index_lsj_trans.pl < $(PDIR)/grc.lsj.perseus-eng0.xml > $@

$(PDIR)/lat.ls.perseus-eng1.xml: $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml
	mkdir -p $(PDIR)
	cp $(LEXICA)/CTS_XML_TEI/perseus/pdllex/lat/ls/lat.ls.perseus-eng1.xml $@

$(PDIR)/latin-analyses.txt: utils/make_latin_analyses.pl $(PBUILD)/lewis-index.txt $(PBUILD)/lewis-index-head.txt $(PBUILD)/lewis-index-trans.txt $(PBUILD)/lat.morph
	./utils/make_latin_analyses.pl \
	    $(PBUILD)/lewis-index.txt $(PBUILD)/lewis-index-head.txt $(PBUILD)/lewis-index-trans.txt \
	    < $(PBUILD)/lat.morph | LC_ALL=C sort > $@

$(PDIR)/greek-analyses.txt: utils/make_greek_analyses.pl $(PBUILD)/lsj-index.txt $(PBUILD)/lsj-index-head.txt $(PBUILD)/lsj-index-trans.txt $(PBUILD)/tlg.morph
	./utils/make_greek_analyses.pl \
	    $(PBUILD)/lsj-index.txt $(PBUILD)/lsj-index-head.txt $(PBUILD)/lsj-index-trans.txt \
	    < $(PBUILD)/tlg.morph | LC_ALL=C sort > $@

.txt.idt:
	./utils/make_index.pl < $< > $@

$(PDIR)/latin-lemmata.txt: utils/make_latin_lemmata.pl $(PBUILD)/lewis-index.txt $(PDIR)/latin-analyses.txt
	./utils/make_latin_lemmata.pl $(PBUILD)/lewis-index.txt < $(PDIR)/latin-analyses.txt > $@

$(PDIR)/greek-lemmata.txt: utils/make_greek_lemmata.pl $(PBUILD)/lsj-index.txt $(PBUILD)/check_tlg $(PDIR)/greek-analyses.txt
	./utils/make_greek_lemmata.pl $(PBUILD)/lsj-index.txt $(TLGDIR) < $(PDIR)/greek-analyses.txt > $@

# The sed below cuts out a notice at the start of the dictionary file
$(PDIR)/gcide.txt: utils/munge_gcide.pl $(GCIDE)
	zcat < $(GCIDE) | sed '1,102d' | ./utils/munge_gcide.pl > $@

clean:
	rm -f $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	rm -f diogenes-browser/perl/Diogenes/unicode-equivs.pl
	rm -f $(PBUILD)/check_phi $(PBUILD)/check_tlg
	rm -f $(PBUILD)/lat.words $(PBUILD)/tlg.words
	rm -f $(PBUILD)/lat.morph $(PBUILD)/tlg.morph
	rm -f $(PBUILD)/lewis-index.txt $(PBUILD)/lewis-index-head.txt $(PBUILD)/lewis-index-trans.txt
	rm -f $(PBUILD)/lsj-index.txt $(PBUILD)/lsj-index-head.txt $(PBUILD)/lsj-index-trans.txt
	rm -f $(DATAFILES)
