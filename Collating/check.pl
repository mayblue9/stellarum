#!/usr/bin/perl

use strict;

use JSON;

my $INFILE = './stars.js';

open(JSONFILE, "<$INFILE") || die("Couldn't open $INFILE $!");
my $json;

{
    local $/;

    $json = <JSONFILE>;
}

my $data = decode_json($json);

my $n = 0;

for my $star ( @$data ) {
    my $ok = '';
    if( $star->{id} == $n + 1 ) {
        $ok = 'ok';
    }
    print "$n,$ok,$star->{id},$star->{name},$star->{ra},$star->{dec},$star->{magnitude},$star->{class}\n";
    $n++;
}

