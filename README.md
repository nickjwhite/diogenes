Diogenes
========

Diogenes is a tool for searching, browsing and reading the databases
of ancient texts, primarily in Latin and Greek, that are published by
the Packard Humanities Institute and the Thesaurus Linguae Graecae.

If you just want to install and run the program, go to the Diogenes
webpage, and download a pre-packaged version for your operating system
from there:

https://d.iogen.es/d

The detailed technical information contained here is only for people
who want to look at the source code of Diogenes and build it for
themselves.

Building
--------

I would prefer not to have Diogenes packaged as part of a larger
(e.g. Linux) free software distribution.  I would rather that users
who are not building the application themselves download the installer
from the Diogenes website.  This is because I use the download
statistics to help justify spending part of my publicly funded time on
this project.

Diogenes can either be built and run as a HTTP server application, or
as a standalone application that seamlessly combines both server and
browser by using the Electron application framework
(https://electronjs.org/).

Diogenes uses several dictionaries, as well as pre-computed morphology
tables, which need to be built or downloaded before use.  If you want
to skip building these, execute this command, which will download the
pre-computed data from Github:

    make -f mk.prebuilt-data

If you would prefer to build the morphology data and dictionaries
yourself, see the instructions below.

Creating the Diogenes icons for various platforms requires a number of
external programs that can be installed with the `librsvg`, `libicns`
and `icoutils` packages on Linux or via Homebrew on OS X.  These, and a
few other files, need to be assembled before Diogenes can be
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
-----------------------

To build an installer for your target platform, run one of the
commands below.  All installers can be built on either Linux or OS X.
You will need to install a number of auxiliary programs, including
`wine`, `innoextract` and `rpm`. All of these can easily be installed
on Linux (make sure to install the 64-bit version of wine) and on OS X
using Homebrew (`brew cask install homebrew/cask/wine-stable`).  To
create Linux installers you will also need to install `fpm`, which is
done via the Ruby package manager (see
https://fpm.readthedocs.io/en/latest/).

[NB. At the moment there is no 32-bit version of Inno Setup available,
which is the windows packager we use. OS X since Catalina will not run
32-bit apps, even under emulation, so 64-bit wine cannot help in this
case.  As a (hopefully) temporary workaround, docker is used instead
of wine to run Inno Setup, which requires installing Docker Desktop
(Mac) or Docker CE (Linux).]

    make installer-w32        # Make a Windows installer
    make installer-mac        # Make a zip file of the Mac app
    make installer-deb64      # Make a Debian package
    make installer-rpm64      # Make an RPM Linux package
    make installer-arch64     # Make a pacman package for Arch Linux

There is also a target to create an OS X pkg, but I have found this to
be unreliable. If another version of Diogenes with the same version
number is already installed, the Mac package installer will leave it
untouched, will not install the new package, and will nonetheless
report success.

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
following commands will download the lexica and the Morpheus parser,
which have been provided by the Perseus project, and repackage them
for Diogenes.

### Step 1

The first step is to generate Greek and Latin wordlists, which are
derived from the TLG wordlist and the Perseus corpus for Greek and
from the PHI, Perseus and DigiLibLT corpora for Latin.  The DigiLibLT
corpus has to be downloaded first by hand after making an account on
their website, but the Perseus corpora are downloaded
automatically. Run this command, specifying the location of the
non-Perseus databases on the command line:

    make -f mk.tlg-phi-words PHIDIR=/path/to/phi TLGDIR=/path/to/tlg_e DIGILIBDIR=~/path/to/digilib


### Step 2

The next step is to generate the morphological data by running
Morpheus over the wordlists.  This part of the build may need to run
on a Linux machine, as Morpheus has had issues on OS X.  If want to
skip this step, you can just download and use the morphological data
from version 3 of Diogenes, which still works fine with version 4.
Run the following command and then go down to Step 3 below:

    make -f mk.morpheus-v3

If you prefer to run Morpheus over the wordlists yourself, you have to
choose between the old version which works well but only compiles on
Linux and the current version, which may be broken but which compiles
on Macs.

To download, compile and run an older but known-good version of
Morpheus, run this command on Linux:

    make -f mk.morpheus-old

The current version of Morpheus in the Perseus github repo has been
updated so that it compiles on Macs, but it is buggy and produces
incomplete and incorrect output. There are newer forks which may have
fixed those issues, but I haven't tested them.  See
e.g. https://github.com/Alatius/morpheus


### Step 3

The next step is to download the LSJ Greek lexicon and the L-S Latin
lexica, which were originally digitized by the Perseus project and
have subsequently been corrected by the Logeion project.  To get the
lexica from Logeion, run:

    make -f mk.lexica-logeion

Alternatively, you can get the Perseus version of the lexica by
running:

    make -f mk.lexica-perseus


### Step 4

The final step is to integrate the morphological data with the lexica,
and package all this in the form that Diogenes requires.  To do this,
run:

    make -f mk.data

The intermediate files generated in the course of all of the steps
above are put the build/ directory, and the final lexical data which
is used used by Diogenes at runtime is put in the dependencies/data
directory, whence it is read by diogenes-server.pl.

### Step 5

There is one more, optional, step, which is to integrate information
on where words can be found in the print versions of the _Thesaurus
Linguae Latinae_ and the first edition of the _Oxford Latin
Dictionary_.  The PDFs of the _TLL_ can be downloaded from the website
of the Bayerische Akademie der Wissenschaften by hand, via a menus
item in the Diogenes Electron application, or by running on the
command line:

    server/tll-pdf-download.pl path/to/destination/folder

If you also have a PDF of the first edition of the _OLD_ that has the
running heads as bookmarks, you can extract the necessary information
from that as well.  To do so, run:

    make -f mk.pdf-data TLLDIR=/path/to/tll/directory OLDFILE=/path/to/old/file

