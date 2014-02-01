#!/usr/bin/perl

# Look up stellar parameters in the big catalogue

# http://www.astronexus.com/node/34

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
my $PARAMS = "$ENV{STELLARUM_FILES}/star_catalogues.csv";
my $OUT = "$ENV{STELLARUM_FILES}/new_parameters.csv";

my @PFIELDS = qw(id name constellation search wikistatus ra dec
                 hip hd bs hascat);


my $LOGCONF = $ENV{STELLARUM_LOG} || die("Need to set a log4j conf file in \$STELLARUM_LOG");

Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum.catalogue');

my $catalogue = Stellarum::Catalogue->new(file => $CATALOGUE);

my $stars = read_csv(
    file => $PARAMS,
    fields => \@PFIELDS
    );

for my $star ( @$stars ) {
    if( $star->{hascat} eq 'yes' ) {
        if( my $starp = $catalogue->lookup(%$star) ) {
            $star->{new_p} = $starp;
            $log->debug("$star->{name} found match: $starp->{spectrum}");
        } else {
            $log->error("$star->{name} not found");
        }
    }
}



