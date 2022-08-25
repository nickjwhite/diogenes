# Changes in Version 4 of Diogenes

## 4.6 (forthcoming)

* Browser front-end updated to Electon version 20 (from version 5).
* This update should eliminate spurious anti-virus warnings.
* PDFs are now shown in a new Diogenes window rather than in an external browser.
* Native version for Macs with Apple processors.
* Minor tweaks to UI, including semi-persistent state for the splash screen and being able to jump to a new passage in the work currently being read.
* Updated icon for Macs (thanks to Helge Baumann).

### Changes implemented earlier but not released
* TLG search results are now presented in (rough) chronological order
  (with huge thanks to Jiang Qian for his assistance).
* Multiple search feature now permits looking for the repetition of
  a word (with thanks to Michael Putnam for the suggestion).
* Many errors in Lewis and Short, especially citation references, have
  been fixed by Logeion (thanks to Helma Dik).
* Diogenes now deals more gracefully with hitting the end of a file
  while browsing.
* There is a new software package (diogenes-epub) for converting Diogenes XML
  output to epub format for e-readers.
* Fixed display of some LSJ headwords.
* Fixed picking up GUI config settings when running server from the Linux command-line.
* Fixed browsing to Val. Max "(ext)" sections and fragments at end of file.
* Latest (short) fasicles of the TLL are downloaded, but cannot yet be used,
  as those PDFs have no bookmarks.
* Fix to bug that interfered with chronological ordering except on Windows.

## 4.5

* Fixed downloading of TLL PDFs after reorganization of BAdW website.
* Fixed OLD and TLL links for words with diacritics.
* Fixed bug in morphological search for Perseus lemmata with commas.
* Fixed some errors in TLL page numbers.
* Fixed LSJ link when parsing ὄνος.

## 4.4

* Added a new menu item to permit the user to set the display font.
* Added a facility to permit user-defined CSS to override display settings.
* Fixed a bug where parsing a word caused the program to hang for certain
  Windows users.
* Fixed bug so that a new window adopts the user-specified window size.
* Reinstated word-list searches for user-defined subsets of the TLG.
* Fixed morphological search functionality that was inadvertently broken in the
  previous release.
* Fixed find-in-page mini-window bug in fullscreen mode.
* Fixed bug where full bibliographical information was displayed inconsistently
  on Windows.
* Fixed some erroneous TLL page references, caused by later corrigenda.

## 4.3

* Highlight clicked word.
* Fix sorting of authors with identical names.
* Automatically clear Electron's HTTP cache when upgrading to a new version of
  Diogenes, which was a source of some subtle bugs.
* Fix export crash when dealing with corrupted input files.
* Now using the Logeion version of Lewis and Short.
* Aligned Greek punctuation with current Unicode recommendations.
* Reinstated searching for Greek words with accents and capital letters.
* Added tooltip for Greek text entry, strict and loose.
* Fixed parsing of capitalized Latin words.
* Improved speed of Perseus look-ups.
* Fixed crash in Juvenal when encountering unknown markup.
* Fixed LSJ short definition for πᾶς.
* Added key binding for Escape key to dismiss sidebar.

## 4.2

* Fixed bug where the morphology of elided Greek forms was not parsed.
* Fixed LSJ short definition for κόλπος.
* Restored behaviour of simple full search to read texts in numerical order.
* Fixed bug in simple searching through sub-corpora.
* Fixed bug when parsing capitalized Greek words with separate parses for upper
  and lower-case.
* Fixed broken .rpm installer for Linux

## 4.1

* Bug that broke find-in-page feature fixed.
* Alphanumeric headings added back to LSJ entries.
* Links to Logeion added.
* "Close window" menu item added.

## 4.0

* Major New Release
