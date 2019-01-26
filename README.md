Diogenes
========

Diogenes is a tool for searching, browsing and reading the databases
of ancient texts, primarily in Latin and Greek, that are published by
the Thesaurus Linguae Graecae and the Packard Humanities Institute.

The information here is only for people who want to delve into
technical details.  If you just want to install and run Diogenes,
ignore the material here and go to the Diogenes webpage instead: 

http://community.dur.ac.uk/p.j.heslin/Software/Diogenes/


Building
--------

Diogenes can either be built and run as a HTTP server application, or
as a standalone application that seamlessly combines both server and
browser.

There are a few files that need to be built before Diogenes can be
run. To do that run this command:

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
-------------------

To build an installer for your target platform, run one of the
commands below.  All installers can be built on either Linux or OS X.
You will need to install a number of auxiliary programs, including
librsvg, iconutils, wine and innoextract.  All of these can easily be
installed on Linux via your distribution and OS X using Homebrew.  You
will also need to install fpm via the Ruby package manager.

    make installer-w32        # Make a Windows installer
    make installer-macpkg     # Make a Mac pkg installer
    make installer-deb64      # Make a Debian package
    make installer-rpm64      # Make an RPM Linux package
    make installer-arch64     # Make a pacman package for Arch Linux

OS X note: If the same version of Diogenes is already installed on the
machine, the Mac package installer will leave it untouched, not
install the package, and report success.


Running the server
------------------

Instead of running the standalone, integrated app, you may prefer to run Diogenes as a server and to connect to it via an ordinary web browser.  The server can be started using the script:

    diogenes-browser/perl/diogenes-server.pl

For full usage details run it like this:

    diogenes-browser/perl/diogenes-server.pl -?


Additional features
-------------------

Diogenes has a number of other features which predate the development of the standalone app and which are no longer fully supported but which may still work.  These include a command-line interface (dio), LaTeX output, and support for a wide variety of pre-Unicode encodings for Ancient Greek.


Building the morphology data & dictionaries
-------------------------------------------

Diogenes uses several dictionaries, as well as pre-computed
morphology tables, which need to be built before use. You can build
them yourself, or download prebuilt copies from:
    https://gitlab.com/diogenes/diogenes-prebuilt/tree/master
Be aware that a lot of memory is required to build the morphology
tables.

The morphology data is derived from Morpheus, from the Perseus
project.  There are also two options for which version of Morpheus to
use.  The current version has some bugs in it that leads to incorrect
output, so it is recommended to use an older version instead.

To build the morphology data using the old, known-good version of
Morpheus:

    PHIDIR=/path/to/phi TLGDIR=/path/to/tlg_e make -f mk.morpheusold all-morph
    
The above step is the only part of the build process that probably has
to be done on a Linux machine.  The old version of Morpheus does not
compile on OS X.  If you want to try the current version of Morpheus,
substitute mk.morpheus for mk.morpheusold.

Then, to build the dictionaries and morphological data in the format
used by Diogenes:

    make -f mk.commondata

The default is to run Morpheus over wordlists derived from the TLG and
from the PHI corpus.  If you would prefer to generate the wordlists
from the Perseus corpora (which have less extensive coverage but are
freely available), edit mk.morpheus[old] to include mk.perseusdata
instead of mk.tlgdata.

Morpheus and its data will be in the build/ directory, and the data
used by Diogenes will be in the dependencies/data directory, which
will automatically be read by diogenes-server.pl.
