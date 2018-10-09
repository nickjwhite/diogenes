# This builds the files needed to run Diogenes.
#
# Note that the dictionaries and morphological data are built using
# different makefiles; read the README for details.

# The v. 0.14 Mac distribution of nwjs.app has Info.plist in UTF-16, which is contrary to Apple spec and breaks this makefile, so do:
# iconv -f UTF-16 -t UTF-8 InfoPlist.strings.orig >InfoPlist.strings

DEPDIR = dependencies

DIOGENESVERSION = 4.0.0

NWJSVERSION = 0.14.7
#NWJSEXTRA = sdk-
#NWJSVERSION = 0.18.0
ENTSUM = 84cb3710463ea1bd80e6db3cf31efcb19345429a3bafbefc9ecff71d0a64c21c
UNICODEVERSION = 7.0.0
UNICODESUM = bfa3da58ea982199829e1107ac5a9a544b83100470a2d0cc28fb50ec234cb840
STRAWBERRYPERLVERSION=5.24.0.1

all: diogenes-browser/perl/Diogenes/unicode-equivs.pl diogenes-browser/perl/Diogenes/EntityTable.pm dist/nwjs/icon256.png diogenes-browser/perl/fonts/GentiumPlus-I.woff diogenes-browser/perl/fonts/GentiumPlus-R.woff

$(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt:
	wget -O $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt
	printf '%s  %s\n' $(UNICODESUM) $@ | sha256sum -c

diogenes-browser/perl/Diogenes/unicode-equivs.pl: utils/make_unicode_compounds.pl $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	./utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@

build/GentiumPlus-5.000-web.zip:
	mkdir -p build
	curl -o $@ https://software.sil.org/downloads/r/gentium/GentiumPlus-5.000-web.zip

diogenes-browser/perl/fonts/GentiumPlus-I.woff: build/GentiumPlus-5.000-web.zip
	unzip -n build/GentiumPlus-5.000-web.zip -d build
	mkdir -p diogenes-browser/perl/fonts
	cp build/GentiumPlus-5.000-web/web/GentiumPlus-I.woff $@

diogenes-browser/perl/fonts/GentiumPlus-R.woff: build/GentiumPlus-5.000-web.zip
	unzip -n build/GentiumPlus-5.000-web.zip -d build
	mkdir -p diogenes-browser/perl/fonts
	cp build/GentiumPlus-5.000-web/web/GentiumPlus-R.woff $@

$(DEPDIR)/PersXML.ent:
	wget -O $@ http://www.perseus.tufts.edu/DTD/1.0/PersXML.ent
	printf '%s  %s\n' $(ENTSUM) $@ | sha256sum -c

diogenes-browser/perl/Diogenes/EntityTable.pm: utils/ent_to_array.pl $(DEPDIR)/PersXML.ent
	printf '# Generated by makefile using utils/ent_to_array.pl\n' > $@
	printf 'package Diogenes::EntityTable;\n\n' >> $@
	./utils/ent_to_array.pl < $(DEPDIR)/PersXML.ent >> $@

nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-linux-x64:
	mkdir -p nw
	cd nw && wget https://dl.nwjs.io/v$(NWJSVERSION)/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-linux-x64.tar.gz
	cd nw && zcat < nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-linux-x64.tar.gz | tar x

linux64: all nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-linux-x64
	mkdir -p linux64
	cp -r nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-linux-x64 linux64
	cp -r diogenes-browser linux64
	cp -r dependencies linux64
	cp -r dist linux64
	printf '#/bin/sh\nd=`dirname $$0`\n"$$d/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-linux-x64/nw" "$$d/dist/nwjs"\n' > linux64/diogenes
	chmod +x linux64/diogenes

nw/nwjs-$(NWJSVERSION)-win-ia32:
	mkdir -p nw
	cd nw && wget https://dl.nwjs.io/$(NWJSVERSION)/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-win-ia32.zip
	cd nw && unzip nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-win-ia32.zip

w32perl:
	mkdir -p w32perl/strawberry
	cd w32perl && wget http://strawberryperl.com/download/$(STRAWBERRYPERLVERSION)/strawberry-perl-$(STRAWBERRYPERLVERSION)-32bit-portable.zip
	cd w32perl/strawberry && unzip ../strawberry-perl-$(STRAWBERRYPERLVERSION)-32bit-portable.zip

rcedit.exe:
	wget https://github.com/electron/rcedit/releases/download/v0.1.0/rcedit.exe

icons: dist/icon.svg
	@echo "Rendering icons (needs rsvg-convert and Adobe Garamond Pro font)"
	mkdir -p icons
	rsvg-convert -w 256 -h 256 dist/icon.svg > icons/256.png
	rsvg-convert -w 128 -h 128 dist/icon.svg > icons/128.png
	rsvg-convert -w 64 -h 64 dist/icon.svg > icons/64.png
	rsvg-convert -w 48 -h 48 dist/icon.svg > icons/48.png
	rsvg-convert -w 32 -h 32 dist/icon.svg > icons/32.png
	rsvg-convert -w 16 -h 16 dist/icon.svg > icons/16.png

dist/nwjs/diogenes.ico: icons
	icotool -c icons/256.png icons/128.png icons/64.png icons/48.png icons/32.png icons/16.png > $@

dist/nwjs/icon256.png: icons
	cp -f icons/256.png $@

dist/app.icns: icons
	png2icns $@ icons/256.png icons/128.png icons/48.png icons/32.png icons/16.png

w32: all nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-win-ia32 w32perl dist/nwjs/diogenes.ico rcedit.exe
	@echo "Making windows package. Note that this requires wine to be"
	@echo "installed, to edit the .exe resources."
	rm -rf w32
	mkdir -p w32
	cp -r nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-win-ia32/* w32
	mkdir -p w32/package.nw
	cp -r diogenes-browser w32/package.nw
	cp -r dependencies w32/package.nw
	cp dist/nwjs/* w32/package.nw
	sed -i -e 's/..\/..\/diogenes-browser\/perl\//diogenes-browser\/perl\//g' w32/package.nw/diogenes-startup.js
	cp -r w32perl/strawberry w32/package.nw
	mv w32/nw.exe w32/diogenes.exe
	wine rcedit.exe w32/diogenes.exe \
	    --set-icon dist/nwjs/diogenes.ico \
	    --set-product-version $(DIOGENESVERSION) \
	    --set-file-version $(DIOGENESVERSION) \
	    --set-version-string CompanyName "The Diogenes Team" \
	    --set-version-string ProductName Diogenes \
	    --set-version-string FileDescription Diogenes

diogenes-windows.zip: w32
	cd w32 && zip -r ../$@ .

nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-osx-x64:
	mkdir -p nw
	cd nw && wget https://dl.nwjs.io/$(NWJSVERSION)/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-osx-x64.zip
	cd nw && unzip nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-osx-x64.zip

mac: all nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-osx-x64 dist/app.icns
	mkdir -p mac
	cp -r nw/nwjs-$(NWJSEXTRA)v$(NWJSVERSION)-osx-x64/nwjs.app mac/Diogenes.app
	mkdir -p mac/Diogenes.app/Contents/Resources/app.nw
	cp -r diogenes-browser mac/Diogenes.app/Contents
	cp -r dependencies mac/Diogenes.app/Contents
	cp -r dist/nwjs/* mac/Diogenes.app/Contents/Resources/app.nw
	cp -r dist/app.icns mac/Diogenes.app/Contents/Resources/
	cp -r dist/app.icns mac/Diogenes.app/Contents/Resources/document.icns
	perl -pi -e 's/CFBundleName = "nwjs"/CFBundleName = "Diogenes"/g; s/CFBundleDisplayName = "nwjs"/CFBundleDisplayName = "Diogenes"/g' mac/Diogenes.app/Contents/Resources/*.lproj/InfoPlist.strings

clean:
	rm -f $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	rm -f diogenes-browser/perl/Diogenes/unicode-equivs.pl
	rm -f $(DEPDIR)/PersXML.ent
	rm -f diogenes-browser/perl/Diogenes/EntityTable.pm
	rm -rf icons nw linux64 mac w32 w32perl
	rm -f rcedit.exe diogenes-windows.zip
