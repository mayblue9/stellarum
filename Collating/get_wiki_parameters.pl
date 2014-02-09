#!/usr/bin/perl

# This script retrieves wikipedia data for the star list.  Now includes
# the Hipparcos and Henry Draper numbers, which are used to get consistent
# magnitude, stellar class and distance parameters from the big catalogue
# file.

use lib $ENV{STELLARUM_LIB};

use strict;
use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';

use Data::Dumper;
use Text::CSV;
use Astro::Coords;
use Log::Log4perl;

use Stellarum qw(stars_from_tweets write_csv read_csv);
use Stellarum::Wikipedia qw(wiki_look);
use Stellarum::Star;


my $LOGCONF = $ENV{STELLARUM_LOG} || die("Need to set a log4j conf file in \$STELLARUM_LOG");

my $MAX_STARS = undef;

my $CLASS_RE = qr/^[CMKFGOBAPWS]$/;
my $DEFAULT_CLASS = 'A';

my $FILEDIR = './Wikifiles/';

my @FIELDS = qw(
    id name constellation
    search wikistatus
    ra dec
    Hipparcos Draper BrightStar hascat
);

my @STARFIELDS = @Stellarum::Wikipedia::FIELDS;

my $TWEETFILE = 'fsvo.js';

my $OUTFILE = 'star_wikidata.csv';


Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum.wiki_stars');

my $stars = stars_from_tweets(file => $TWEETFILE);

die("No stars in tweet file $TWEETFILE!")  unless $stars;

my @nowiki = map { $_->{wiki} ? () : $_ } @$stars;

if( @nowiki ) {
    $log->fatal("Empty wiki searches:\n" . Dumper(\@nowiki) . "\n");
    die;
}

my $outstars = [];

$log->info("Getting star data from Wiki/wikicache");

my $n = 0;

my $collect = {};

for my $star ( @$stars ) {
    $log->debug("Star $star->{name} $star->{wiki}");
    my $wiki_params = wiki_look(dir => $FILEDIR, star => $star);
    if( $wiki_params ) {
        $star->set(parameters => $wiki_params);
    }

    if( $MAX_STARS && $n > $MAX_STARS ) {
        $log->info("Reached MAX_STARS $MAX_STARS");
        last;
    }
    $n++;
}



$log->info("Writing to $OUTFILE");

write_csv(
    file => $OUTFILE,
    fields => \@FIELDS,
    records => $stars
);

for my $field ( sort keys %$collect ) {
    my @stars = keys %{$collect->{$field}};
    $log->debug(sprintf("%25s", $field) . ': ' . scalar(@stars));
}






