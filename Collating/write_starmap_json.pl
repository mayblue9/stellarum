#!/usr/bin/perl

# This script takes the JSON tweets and the definitive stellar parameters
# file, and writes out the JSON stars file for the visualiser.

use strict;
use utf8;

use lib $ENV{STELLARUM_LIB};



use Data::Dumper;
use Log::Log4perl;

use Stellarum qw(stars_from_tweets read_csv write_csv);
use Stellarum::Star;

my $LOGCONF = './log4j.properties';

my $MAX_STARS = undef;


my @FIELDS = qw(
    id name designation greek constellation
    search wikistatus
    ra1 ra2 ra3 dec1 dec2 dec3 ra dec
    appmag_v class mass radius
    text xrefs
    distance appmag absmag spectrum colourindex
);




Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum');

my $TWEETFILE = "$ENV{STELLARUM_FILES}/fsvo.js";
my $PARAMETERS = "$ENV{STELLARUM_FILES}/new_parameters.csv";

my $CSVOUT = "$ENV{STELLARUM_FILES}/stars_new.csv";
my $JSONOUT = "$ENV{STELLARUM_FILES}/stars_new.js";

my $EXTRA_JSON = <<EOJS;

var starNames = [];

for (var i = 0; i < stars.length; i++ ) {
    starNames.push(stars[i].name);
}

var constNames = constellations.keys()
EOJS

my $stars = stars_from_tweets(file => $TWEETFILE);

$log->info("Getting star data from spreadsheet: $PARAMETERS");

my $parameters = read_csv(file => $PARAMETERS, fields => \@FIELDS);

my $outstars = [];

my @fields = qw(
       constellation ra1 ra2 ra3 dec1 dec2 dec3 ra dec 
       text xrefs
       appmag absmag spectrum distance colourindex
    );

# NOTE: newids now start with 0, not 1, so that they correspond
# with array indices.

my $newid = 0;
$outstars = [];
for my $csvstar ( @$parameters ) {
    my $id = $csvstar->{id};
    my $star;
    if( $id ) {
        $star = shift @$stars;
        while( $star && $star->{name} ne $csvstar->{name} ) {
            if( $star ) {
                $log->error("Unmatched star $star->{name} not found in CSV: got '$csvstar->{name}'");
                $log->debug(Dumper({ star => $star }));
                $star = shift @$stars;
            } else {
                $log->fatal("Ran out of stars.");
                die;
            }
        }
    } else {
        # Inserts - stars not in the original list, and thus without
        # a corresponding JSON entry
        $star = parse_tweet(
            id => $newid,
            name => $csvstar->{name},
            bayer => $csvstar->{designation},
            text => $csvstar->{text}
            );
    }
    for my $field ( @fields ) {
        $star->{$field} = $csvstar->{$field};
    }
    my @coords = astro_coords(
        [ $star->{ra1}, $star->{ra2}, $star->{ra3} ],
        [ $star->{dec1}, $star->{dec2}, $star->{dec3} ]
        );
    if( @coords ) {
        ( $star->{ra}, $star->{dec} ) = @coords;
    } else {
        $log->warn("Bad coords for $id $star->{name}");
    }
    $star->{id} = $newid;
    
    $log->debug("$id $newid $star->{name}");
    $newid++;
    push @$outstars, $star;
}

add_xrefs(stars => $outstars);

write_csv(
    records => $outstars,
    file => $CSVOUT,
    fields => \@FIELDS
);

write_json(stars => $outstars);





sub add_xrefs {
    my %params = @_;

    my $stars = $params{stars};
    my $ids = {};

    for my $star ( @$stars ) {
        my $name = $star->{name};
        if( !$ids->{$name} ) {
            $ids->{$name} = $star->{id};
        } else {
            $ids->{$name} = 'overload';
            $log->warn("Overloaded star $name $star->{id}");
        }
    }

    my $names = join('|', reverse sort keys %$ids);

    for my $star ( @$stars ) {
        #while we're here, remove (q.v.) and (qq.v.)
        if( $star->{text} =~ s/\(qq?\.v\.\)\s*//g ) {
            $log->debug("Removed q.v. or qq.v. in $star->{id} $star->{name}");
        }
        
        # override with manual xrefs, which are a ; separated list
        
        if( $star->{xrefs} ) {
            my @ids = split(/;\s*/, $star->{xrefs});
            $log->info("Manual xrefs for $star->{id} $star->{name}: " . join('; ', @ids));
            my $manualid = sub {
                my ( $name ) = @_;
                my $id = shift @ids;
                if( !$id ) {
                    $log->error("Ran out of manual xrefs for $star->{id} $star->{name} ($name)");
                }
                return "<span class=\"link\" star=\"$id\">$name<\/span>"
            };

            my $count = ( $star->{text} =~ s/($names)/&$manualid($1)/ge );
            if( $count ) {
                $log->debug("Resolved manual xrefs ($count) in $star->{id} $star->{name}");
            }
        } else {
            my $count = ( $star->{text} =~ s/($names)/<span class=\"link\" star=\"$ids->{$1}\">$1<\/span>/g );
            if( $count ) {
                $log->debug("Resolved xrefs ($count) in $star->{id} $star->{name}");
            }
        }

    }
}






sub write_json {
    my %params = @_;

    my $stars = $params{stars};

    my $json = JSON->new();

    my $data = [];
    my $constellations = {};


    for my $star ( @$stars ) {
        
        if ( defined $star->{ra} ) {
            my $js = $star->json();
            push @$data, $js;

            if( $js->{const} ) {
                push @{$constellations->{$js->{const}}}, $js->{id};
            }
            
        } else {
            $log->warn("Star $star->{name} has no ra");
        }
    }
    
   
    my $stars_js = $json->pretty->encode($data);
    my $const_js = $json->pretty->encode($constellations);
    
    open(my $fh, ">:encoding(utf8)", $JSONOUT) || die("Couldn't write to $JSONOUT: $!");

    print $fh "var stars = $stars_js;\n\n";
    print $fh "var constellations = $const_js;\n\n";
#    print $fh $EXTRA_JSON . "\n\n";
    close $fh;
} 





