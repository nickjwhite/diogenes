Diogenes
========

Diogenes is a tool for searching, browsing and reading the databases
of ancient texts, primarily in Latin and Greek, that are published by
the Thesaurus Linguae Graecae and the Packard Humanities Institute.

Diogenes can either be built and run as a HTTP server application, or
as a standalone application.


Building
--------

There are a few files that need to be built before Diogenes can be
run. To do that run this command:

  make


Building Diogenes standalone
----------------------------

To build standalone diogenes, use one of these make commands
according to the platform you're building for:

  make linux64   # for linux (64 bit) build
  make w32       # for windows build
  make mac       # for mac osx build


Running the server
------------------

The Diogenes server can be started using the script:

  diogenes-browser/perl/diogenes-server.pl

For full usage details run it like this:

  diogenes-browser/perl/diogenes-server.pl -?


Building the morphology data & dictionaries
-------------------------------------------

Diogenes uses several dictionaries, as well as pre-computed
morphology tables, which need to be built before use. You can build
them yourself, or download prebuilt copies from:
  https://gitlab.com/diogenes/diogenes-prebuilt/tree/master
Be aware that a lot of memory is required to build the morphology
tables (around 25GiB).

There are two options in building the morphology data, either using
wordlists from Perseus' free corpus, or using the TLG and PHI
wordlists. The latter has the advantage of greater coverage when
reading TLG and PHI texts, while the former has the advantage of
being freely available.

To build morphology and dictionaries using the Perseus corpus:

  make -f mk.perseusdata

To build morphology and dictionaries using the TLG and PHI corpus:

  make -f mk.tlgdata PHIDIR=/path/to/phi TLGDIR=/path/to/tlg_e

The morphology data and dictionary files will be built in the
dependencies/data/ directory, which will automatically be read
by diogenes-server.pl.
