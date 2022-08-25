Diogenes
========

Diogenes is a tool for searching, browsing and reading the databases
of ancient texts, primarily in Latin and Greek, that were once
published by the Packard Humanities Institute and the Thesaurus
Linguae Graecae.

If you just want to install and run the program, go to the Diogenes
webpage, and download a pre-packaged version for your operating system
from there:

[https://d.iogen.es/d](https://d.iogen.es/d)

The detailed technical information contained here is only intended for
people who want to look at the source code of Diogenes and build it
for themselves.

Building
--------

I would prefer not to have Diogenes packaged as part of a larger
(e.g. Linux) distribution; I would rather that users who are not
building the application themselves download the installer from the
Diogenes website.  This is because I use the download statistics to
help justify spending part of my publicly funded time on this project.

Diogenes can either be built and run as a HTTP server application, or
as a standalone application that seamlessly combines both server and
browser by using the [Electron](https://electronjs.org/) application
framework.

Diogenes uses several dictionaries, as well as pre-computed morphology
tables, which need to be built or downloaded before use.  If you want
to skip building these, execute this command, which will download the
pre-computed data from Github:

    make -f mk.prebuilt-data

If you would prefer to build the morphology data and dictionaries
yourself, see the instructions below.

Preliminaries
-------------

Creating the Diogenes icon file for Windows requires some utility
programs, which can be installed on OS X (the Homebrew packages
are`librsvg` and `icoutils`) and on Linux (the Debian packages are
`librsvg2-bin` and `icoutils`).

Creating the Mac icon file needs to be done on OS X and requires
installing the `png2icns` package for Node.js: install Node via
Homebrew and then run `npm install png2icns -g`. (There is an entirely
different png2icns program that also runs on Linux, but it looks
obsolescent.)

Once you have installed those utility programs, you can run this
command, which will create the icons and collect a number of other
required files:

    make

Building the Electron app
-------------------------

To build the standalone Diogenes application which has the server and
client browser integrated via Electron, use one of these make commands
according to the platform you're building for:

    make linux64   # for linux (64 bit) build
    make w32       # for windows build
    make mac-x64   # for mac osx build (Intel)
    make mac-arm64 # for mac osx build (Apple silicon)
 
Building the installers
-----------------------

All of the installers can be built on either Linux or OS X.  To create
the Linux installers you will need to install `fpm`, which is done via
the Ruby package manager [(see
instructions)](https://fpm.readthedocs.io/en/latest/installing.html),
and for the RPM installer you will also need to install `rpm`, which
is available on Homebrew.

The Windows installer is created with Inno Setup, which is a Windows
application.  In principle, this can be run via the Wine emulator,
which requires installing `wine` (64-bit version) and `innoextract`,
both of which are available on Linux and via Homebrew (`brew cask
install homebrew/cask/wine-stable`).  But Inno Setup is currently only
available as a 32-bit app, and OS X will not run these anymore, even
under emulation; 64-bit wine cannot help in this case.  As a
workaround, Docker is currently used instead of wine to run Inno
Setup, which requires installing Docker Desktop (Mac) or Docker CE
(Linux).

There is a target in the Makefile to create an OS X pkg, but I don't
recommend using it: if another version of Diogenes with the same
version number is already installed, the Mac package installer will
leave it untouched, will not install the new package, and will
nonetheless report success.  The Diogenes.app for OS X is distributed
in a simple zip file, which seems to work fine for users.

To build an installer for your target platform, run one of the
commands below.

    make installer-w32        # Make a Windows installer
    make installer-mac        # Make zip files of the Mac app for both Intel and ARM
    make installer-deb64      # Make a Debian package
    make installer-rpm64      # Make an RPM Linux package
    make installer-arch64     # Make a pacman package for Arch Linux


Running the server
------------------

Instead of running the standalone, integrated app, you may prefer to
run Diogenes as a server and to connect to it via an ordinary web
browser.  The server can be started using the script:

    server/diogenes-server.pl

For full usage details run it like this:

    server/diogenes-server.pl -?

Additional features
-------------------

Diogenes has a number of other features which predate the development
of the standalone app and which are no longer fully supported but
which may still work.  These include a command-line interface
(`diogenes-cli.pl`), LaTeX output, and support for a wide variety of
pre-Unicode encodings for Ancient Greek.

Various options for XML export are available by running the
`server/xml-export.pl` script from the command line.

Building the morphology data & dictionaries
-------------------------------------------

Instead of downloading the pre-built lexical data via
`make -f mk.prebuilt-data`, you can build it from scratch. The
following steps will download the lexica and the Morpheus parser,
which have been provided by the Perseus project, and repackage them
for Diogenes.

1. Wordlists

    The first step is to generate Greek and Latin wordlists, which for
    Greek are derived from the Perseus corpus and the TLG wordlist;
    and for Latin from the PHI, Perseus and DigiLibLT corpora.  The
    DigiLibLT corpus has to be downloaded first by hand after making
    an account on their website, but the Perseus corpora are
    downloaded automatically. Run this command, specifying the
    location of the non-Perseus databases on the command line:

        make -f mk.wordlists PHIDIR=/path/to/phi TLGDIR=/path/to/tlg_e DIGILIBDIR=~/path/to/digilib

1. Morphology

    The next step is to generate the morphological data by running
    Morpheus over the wordlists.  This part of the build may need to
    run on a Linux machine, as Morpheus has had issues on OS X.  If
    want to skip this step, you can just download and use the
    morphological data from version 3 of Diogenes, which still works
    fine with version 4.  Run the following command and then go down
    to Step 3 below:

        make -f mk.morpheus-v3

    If you prefer to run Morpheus over the wordlists yourself, you
    have to choose between the old version which works well but only
    compiles on Linux and the current version, which may be broken but
    which compiles on Macs.

    To download, compile and run an older but known-good version of
    Morpheus, run this command on Linux:

        make -f mk.morpheus-old

    The current version of Morpheus in the Perseus github repo has
    been updated so that it compiles on Macs, but it is buggy and
    produces incomplete and incorrect output. There are newer forks
    which may have fixed those issues, but I haven't tested them.  See
    e.g. [here](https://github.com/Alatius/morpheus).

1. Lexica

    The next step is to download the LSJ Greek lexicon and the L-S
    Latin lexicon, which were originally digitized by the Perseus
    project and have subsequently been corrected by the Logeion
    project.  To get the lexica from Logeion, run:

        make -f mk.lexica-logeion

    Alternatively, you can get the Perseus version of the lexica by
    running:

        make -f mk.lexica-perseus

1. Integration

    The next step is to integrate the morphological data with the
    lexica, and package all this in the form that Diogenes requires.
    To do this, run:

        make -f mk.data

    The intermediate files generated in the course of all of the steps
    above are put the build/ directory, and the final lexical data
    which is used used by Diogenes at runtime is put in the
    dependencies/data directory, whence it is read by
    diogenes-server.pl.

1. PDFs of Lexica

    There is one more, optional, step, which is to integrate
    information on where words can be found in the print versions of
    the _Thesaurus Linguae Latinae_ and the first edition of the
    _Oxford Latin Dictionary_.  The PDFs of the _TLL_ can be
    downloaded from the website of the Bayerische Akademie der
    Wissenschaften by hand, via a menus item in the Diogenes Electron
    application, or by running on the command line:

        server/tll-pdf-download.pl path/to/destination/folder

    If you also have a PDF of the first edition of the _OLD_ that has
    the running heads as bookmarks, you can extract the necessary
    information from that as well.  To do so, run:

        make -f mk.pdf-data TLLDIR=/path/to/tll/directory OLDFILE=/path/to/old/file
