#!/usr/bin/perl -w
use strict;

my %entities;
my $a;
my $b;

while (<>) {
    next if m/^<!--/;
    next unless m/<!ENTITY\s+(\S+)\s+"(.*?)"\s*>/;

    my $name = $1;
    my $code = $2;

    if ( $code =~ m/^&#x(\S+);$/ ) {
        $entities{$name} = "chr(0x$1)";
    } else {
        # Only set a string code if a character code hasn't already been set
        if ( ! defined( $entities{$name} ) || ! $entities{$name} =~ m/^chr/ ) {
            $entities{$name} = "'$code'";
        }
    }
}

# Some entities reference other entities, so we should set their
# content to the code of the entity they reference
foreach $a (keys %entities) {
    if ( $entities{$a} =~ m/&(\S+);/ ) {
        my $code = $1;
        foreach $b (keys %entities) {
            if ( $b =~ m/$code/ ) {
                $entities{$a} = $entities{$b};
            }
        }
    }
}

print "%Diogenes::EntityTable::table = (\n";

foreach $a (sort keys %entities) {
    print "	'$a' => $entities{$a},\n";
}

print ");\n";
