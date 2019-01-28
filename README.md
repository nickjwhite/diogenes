Diogenes
========

Diogenes is a tool for searching, browsing and reading the databases
of ancient texts, primarily in Latin and Greek, that are published by
the Thesaurus Linguae Graecae and the Packard Humanities Institute.

The information here is only for people who want to delve into the
technical details of Diogenes.  If you just want to install and run
it, ignore all this and go to the Diogenes webpage instead:

http://community.dur.ac.uk/p.j.heslin/Software/Diogenes/

Building
--------

Diogenes can either be built and run as a HTTP server application, or
as a standalone application that seamlessly combines both server and
browser by using the Electron application framework
(https://electronjs.org/).

Diogenes uses several dictionaries, as well as pre-computed morphology
tables, which need to be built or downloaded before use.  If you want
to skip building these, execute this command, which will download the
pre-computed data from Github:

    make -f mk.prebuilt

If you would prefer to build the morphology data and dictionaries
yourself, see the instructions below.

There are a few other files that need to be assembled before Diogenes
can be run. To do that run this command:

    make

Building Diogenes standalone
----------------------------

To build the standalone Diogenes application, with integrated server
and browser, use one of these make commands according to the platform
you're building for:

    make linux64   # for linux (64 bit) build
    make w32       # for windows build
    make mac       # for mac osx build

Building the installers
-----------------------

To build an installer for your target platform, run one of the
commands below.  All installers can be built on either Linux or OS X.
You will need to install a number of auxiliary programs, including
`librsvg`, `iconutils`, `wine` and `innoextract`.  All of these can
easily be installed on Linux via your distribution and OS X using
Homebrew.  You will also need to install `fpm` via the Ruby package
manager (see https://fpm.readthedocs.io/en/latest/).

    make installer-w32        # Make a Windows installer
    make installer-macpkg     # Make a Mac pkg installer
    make installer-deb64      # Make a Debian package
    make installer-rpm64      # Make an RPM Linux package
    make installer-arch64     # Make a pacman package for Arch Linux

OS X note: If another version of Diogenes with the same version number
is already installed, the Mac package installer will leave it
untouched, will not install the new package, and will nonetheless
report success.

Running the server
------------------

Instead of running the standalone, integrated app, you may prefer to
run Diogenes as a server and to connect to it via an ordinary web
browser.  The server can be started using the script:

    diogenes-browser/perl/diogenes-server.pl

For full usage details run it like this:

    diogenes-browser/perl/diogenes-server.pl -?

Additional features
-------------------

Diogenes has a number of other features which predate the development
of the standalone app and which are no longer fully supported but
which may still work.  These include a command-line interface (dio),
LaTeX output, and support for a wide variety of pre-Unicode encodings
for Ancient Greek.

Building the morphology data & dictionaries
-------------------------------------------

Instead of downloading the pre-built lexical data via `mk-prebuilt`,
you can build it from scratch.  The following commands will download
the lexica and the Morpheus parser, which have been provided by the
Perseus project, and repackage them for Diogenes.

The first step is to generate Greek and Latin wordlists.  The default
is to use wordlists derived from the TLG and from the PHI Latin
database. Run this command, specifying the location of the databases
on the command line:

    make -f mk.tlg-phi-words PHIDIR=/path/to/phi TLGDIR=/path/to/tlg_e

If you would prefer to generate the wordlists from the Perseus corpora
(which have less extensive coverage but are freely available), run
this command instead:

    make -f mk.perseus-words

The next step is to generate the morphological data by running
Morpheus over the wordlists.  This is the only part of the build
process that probably requires running it on a Linux machine, as
Morpheus does not compile on OS X.  If you are on OS X and want to
skip this step, you can just download and use the morphological data
from version 3 of Diogenes, which still works fine with version 4.
Run the following command and then go down to the final step below:

    make -f mk.morpheus-v3

In order to run Morpheus over the wordlists, you have to choose
between compiling an old version which works well and compiling the
current version, which is broken.

To download, compile and run an older but known-good version of
Morpheus, run this command:

    make -f mk.morpheus-old

The current version of Morpheus from the Perseus project has some bugs
in it that leads to incomplete and incorrect output, so it is
recommended to use the older version.  But if you want to try the
current version, do this instead:

    make -f mk.morpheus-broken


The final step is to download the lexica, integrate the morphological
data with the lexica, and package all this in the form that Diogenes
requires.  To do this, run:

    make -f mk.data

The intermediate files generated in the course of all of the steps
above are put the build/ directory, and the final lexical data used by
Diogenes is put in the dependencies/data directory, whence it is read
by diogenes-server.pl.
