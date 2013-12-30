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
use Stellarum::Wikipedia qw(wiki_look);
use Stellarum::Star;


my $LOGCONF = $ENV{STELLARUM_LOG} || die("Need to set a log4j conf file in \$STELLARUM_LOG");

my $MAX_STARS = undef;

my $CLASS_RE = qr/^[CMKFGOBAPWS]$/;
my $DEFAULT_CLASS = 'A';

my $FILEDIR = './Wikifiles/';

my @FIELDS = qw(
    id name designation greek constellation
    search wikistatus
    ra dec
    appmag_v absmag_v class mass radius distance
);

my $INFILE = 'fsvo.js';

my $OUTFILE = 'new_wiki_stars.csv';


Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum.wiki_stars');



open(JSONFILE, "<$INFILE") || die("Couldn't open $INFILE $!");
my $json;

{
    local $/;

    $json = <JSONFILE>;
}

my $data = decode_json($json);

my $stars = stars_from_tweets(tweets => $data->{tweets});




my @nowiki = map { $_->{wiki} ? () : $_ } @$stars;

if( @nowiki ) {
    $log->fatal("Empty wiki searches:\n" . Dumper(\@nowiki) . "\n");
    die;
}

my $outstars = [];

$log->info("Getting star data from Wiki/wikicache");

my $n = 0;

for my $star ( @$stars ) {
    my $wiki_params = wiki_look(dir => $FILEDIR, star => $star);
    if( $wiki_params ) {
        $star->update(parameters => $wiki_params);
    }
    $log->debug("$star->{name} $wiki->{wikistatus}");
    if( $MAX_STARS && $n > $MAX_STARS ) {
        $log->info("Reached MAX_STARS $MAX_STARS");
        last;
    }
    $n++;
}

write_csv(
    file => $OUTFILE,
    fields => \@FIELDS,
    records => $stars
);






