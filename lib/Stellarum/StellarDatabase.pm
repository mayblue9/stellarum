package Wikipedia::StellarDatabase;

use strict;

use base Exporter;
use WWW::Mechanize;

our @EXPORT_OK = qw(sd_look);

our $URL = 'http://www.stellar-database.com/Scripts/search_star.exe?Name=$NAME';


my $log = Log::Log4perl->get_logger('stellarum.stellardatabase');

my $wm = WWW::Mechanize->new();

sub sd_look {
    my %params = @_;

    my $name = $params{name};
    my $bayer = $params{bayer};

    $log->debug("Looking up name $name");
    if( my $results = get_sd(search => $name) ) {
        return $results;
    }

    $log->debug("Looking up Bayer $bayer");
    if( my $results = get_sd(search => $bayer) ) {
        return $results;
    }
    
    $log->debug("Both lookups failed!");
    return undef;
}


sub get_sd {
    my ( $term ) = @_;

    my $url = $URL;

    my $term =~ s/\s/\+/g;

    if( !$url =~ s/\$SEARCH/$term/ ) {
        $log->error("Couldn't substitute search term in $URL");
        return undef;
    }

    $self->debug("Search for $term");
    
    if( my $response = $wm->get($url) ) {
        my $html = $response->content();

        if( $html =~ /No star name/ ) {
            $self->debug("'$term' not found");
            return undef;
        }

        return $html;
    }

    $self->error("WWW::Mechanize didn't return a response");

    return undef;
}


1;    
    
