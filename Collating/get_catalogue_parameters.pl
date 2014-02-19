#!/usr/bin/perl

# This script takes the hand-corrected stellar parameters CSV file,
# looks up the stars in the star_catalogues.csv file to get a Hipparcos
# or HD number, then retrieves their parameters from the big database
# and writes out a fresh set of parameters as new_parameters.csv

# http://www.astronexus.com/node/34

# Original star paramaters -> star_parameters.csv
# Catalogue look up file which maps stellarum IDs to catalogue numbers
#                         -> star_catalogues.csv
# New file with parameters from the big database
#                         -> new_parameters.csv

# This is missing some stars (eg HIND'S CRIMSON STAR) which are in the
# star_parameters.csv but not in the tweets for some reason.

use lib $ENV{STELLARUM_LIB};

use strict;
use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';

use JSON;
use Data::Dumper;
use Text::CSV;
use Astro::Coords;
use Log::Log4perl;

use Stellarum qw(stars_from_tweets write_csv read_csv);
use Stellarum::Catalogue;

my $CATALOGUE = "$ENV{STELLARUM_FILES}/hygxyz.csv";
my $CATS = "$ENV{STELLARUM_FILES}/star_catalogues.csv";
my $PARS = "$ENV{STELLARUM_FILES}/star_parameters.csv";
my $OUT = "$ENV{STELLARUM_FILES}/new_parameters.csv";

my @CFIELDS = qw(id name constellation search wikistatus ra_cat dec_cat
                 hip hd bs hascat);

my @ORIGFIELDS = qw(
    id name designation greek constellation
    search wikistatus
    ra1 ra2 ra3 dec1 dec2 dec3 ra dec
    appmag_v class mass radius
    text xrefs
);

my @NPFIELDS = qw(ra_cat dec_cat hip hd bs bayer distance appmag absmag spectrum colourindex);


my @OUTFIELDS = ( @ORIGFIELDS, @NPFIELDS );

my $LOGCONF = $ENV{STELLARUM_LOG} || die("Need to set a log4j conf file in \$STELLARUM_LOG");

Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum.catalogue');

$log->info("Loading catalogues...");

my $catalogue = Stellarum::Catalogue->new(file => $CATALOGUE);



my $starcat = starcats();

$log->info("Loading stars...");

my $starsorig= read_csv(
    file => $PARS,
    fields => \@ORIGFIELDS
    );

$log->info("Collating parameters...");


STAR: for my $star ( @$starsorig ) {
    my $tag = "[$star->{id} $star->{name}]";
    $log->info($tag);
    my $cats = $starcat->{$star->{name}};
 
    if( ! $cats ) {
        $log->error("$tag not found in star cats");
        next STAR;
    }

    if( $cats->{name} ne $star->{name} ) {
        $log->error("Name error: $cats->{id} $cats->{name}");
        next STAR;
    }

    if( $cats->{hascat} eq 'no' ) {
        $log->error("$tag has no catalogue numbers");
        next STAR;
    }
    if( my $starp = $catalogue->lookup(%$cats) ) {
        $starp->{ra_cat} = $starp->{ra};
        $starp->{dec_cat} = $starp->{dec};
        delete $starp->{ra};
        delete $starp->{dec};
        for my $pfield ( @NPFIELDS ) {
            $star->{$pfield} = $starp->{$pfield};
        }
        $log->debug("$tag found match: $starp->{spectrum}");
    } else {
        $log->error("$tag catalogue lookup failed");
    }
    $log->debug("Star $tag");
}

# Writing is a bit fucked up because this code is a mess.
#
# The IDs in the csv files don't matter because stars.pl is going to
# reassign them.  star_parameters.csv has IDs that match the original
# JSON files and stars added in later (usually because of bad characters
# or something) have an empty ID.

# To match against the catalogue parameters, I'm now using names, but
# leaving the stars with blank IDs still in there so that stars.pl will
# still pick them up.  Have to get the extra parameters for the blanks
# by hand. 


$log->info("Writing out ${OUT} ...");



write_csv(
    file => $OUT,
    fields => \@OUTFIELDS,
    records => $starsorig
    );


$log->info("Done.");




sub starcats { 
    my $sc = {};
    my $rows= read_csv(
        file => $CATS,
        fields => \@CFIELDS
        );

    for my $row ( @$rows ) {
        $sc->{$row->{name}} = $row;
    }
    
    return $sc;
}
