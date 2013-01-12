#!/usr/bin/perl

use strict;

use Astro::Coords;


my $ra = "14:15:39.7";
my $dec = "19:10:56";

my $coords = Astro::Coords->new(
    name => 'test',
    ra => $ra,
    dec => $dec,
    type => 'J2000',
    units => 'sexagesimal'
    );

if( $coords ) {

    my ( $r, $d ) = $coords->radec();

    print "RA $ra => " . $r->degrees() . "\n";
    print "DEC $dec => " . $d->degrees() . "\n";
    
} else {
    print "Couldn't construct Astro::Coords object\n";
}
