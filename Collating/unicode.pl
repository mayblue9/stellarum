#!/usr/bin/perl

use strict;
use utf8;
use charnames ':full';




for my $code ( 0..255 ) {
    my $hexcode = sprintf("%04X", $code);
    my $charname = charnames::viacode($code);
    my $esc = "print \"\\N{$charname}\"";
    print "$hexcode ";
    eval $esc;
    print " $charname\n";
}


