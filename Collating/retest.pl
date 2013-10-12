#!/usr/bin/perl

use strict;
use utf8;
use charnames ':full';

my $TEST = <<EOTXT;
{{Starbox observe 
| epoch = J2000 
| constell = [[Eridanus (constellation)|Eridanus]] 
| ra = {{RA|01|37|42.84548}}<ref name=aaa474_2_653/>
| dec = {{DEC|–57|14|12.3101}}<ref name=aaa474_2_653/>
| appmag_v = 0.445<ref name=mnassa31_69/>
}}`
EOTXT


my $ANGLE_RE = qr/\{\{RA\|([^|]+)\|([^|]+)\|([/;

if( $TEST =~ /\{\{RA\|$ANGLE_RE/s ) {
    print "RA = " . join('-', $1, $2, $3) . "\n\n";
}

if( $TEST =~ /\{\{DEC\|$ANGLE_RE/s ) {
    print "DEC = " . join('-', $1, $2, $3) . "\n\n";
}



