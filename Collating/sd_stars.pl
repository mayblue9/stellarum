#!/usr/bin/perl

# Parses wikipedia entries for stellar parameters.  Separated out from
# the main stars.pl script, which now uses a parameters spreadsheet as its
# source of data.

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
use Stellarum::Star;
use Stellarum::StellarDatabase qw(sd_look);

my $PAUSE = 10;

my $LOGCONF = $ENV{STELLARUM_LOG} || die("Need to set a log4j conf file in \$STELLARUM_LOG");

my $MAX_STARS = 10;

my $CLASS_RE = qr/^[CMKFGOBAPWS]$/;
my $DEFAULT_CLASS = 'A';

my $FILEDIR = './StellarDatabase/';

my @FIELDS = qw(
    id name designation greek constellation
    search wikistatus
    ra dec
    appmag_v absmag_v class mass radius distance
);

my $INFILE = 'fsvo.js';


Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum.sd_stars');



open(JSONFILE, "<$INFILE") || die("Couldn't open $INFILE $!");
my $json;

{
    local $/;

    $json = <JSONFILE>;
}

my $data = decode_json($json);

my $stars = stars_from_tweets(tweets => $data->{tweets});

my $outstars = [];

$log->info("Getting star data from www.stellar-database.com");

my $n = 0;

for my $star ( @$stars ) {
    $log->debug("Star $star->{name} ($star->{bayer})");
    if( my $results = sd_look(%$star) ) { 
        $log->debug("Got results.");
    } else {
        $log->debug("Search failed.");
    }

    sleep $PAUSE;
    
    if( $MAX_STARS && $n > $MAX_STARS ) {
        $log->info("Reached MAX_STARS $MAX_STARS");
        last;
    }
    $n++;
}

# write_csv(
#     file => $OUTFILE,
#     fields => \@FIELDS,
#     records => $stars
# );






