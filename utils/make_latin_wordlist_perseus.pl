#!/bin/sh

usage="Usage: $0 perseusdir

Outputs a list of all Latin words encountered in a Perseus
corpus, with their frequency."

test $# -ne 1 && echo "$usage" && exit 1

export LC_ALL=C # ensure reproducible sorting

find "$1" -type f -name '*-lat?.xml' | sort | while read i; do
	# Strip XML, separate by word
	cat "$i" \
	| sed '1,/<body>/ d; /<\/body>/,$ d' \
	| sed 's/<[^>]*>//g; s/\&[^;]*;//g' \
	| awk '{for(i=1;i<=NF;i++) {printf("%s\n", $i)}}' \
	| sed '/[0-9]/d; /\[/d; /\]/d' \
	| sed '/[!?"“”<>\r]/d'
done | sort | uniq
