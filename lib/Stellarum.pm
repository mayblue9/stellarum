package Stellarum;

# core package for loading stars from the twitter archive and writing
# them out in various formats

use lib $ENV{STELLARUM_LIB};

use strict;
use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';

use Text::CSV;
use Data::Dumper;

use base qw(Exporter);

our @EXPORT_OK = qw(stars_from_tweets write_csv read_csv);

use Log::Log4perl;
use Stellarum::Star;

=head1 METHODS

=item stars_from_tweets(tweets => $aref)

Take a JSON represenation of tweets about stars, parses them and
returns an arrayref of Stellarum::Star objects.  The tweets are
expected to be an arrayref of hashrefs with a field 'text' containing
text like this:

    RIGIL KENTAURUS (\u03b1 Centauri) Triple system inhabited by centaurs, the coincidence of names being a race-memory of their brief visit to SOL.

It converts the Bayer designation to a Javascript-web-friendly format and
adds name and text fields.

=cut


our $log = Log::Log4perl->get_logger('stellarum');    


sub stars_from_tweets {
    my %params = @_;

    my $stars = [];
    my $id = 1;
    
    my $tweets = $params{tweets};
    
    for my $tweet ( @$tweets ) {
        my $text = $tweet->{text};
        
        if( $text =~ /^([A-Z'\s]+)\s+\(([^),]*)\)\s+(.*)/ ) {
            my $star = Stellarum::Star->new(
                id => $id,
                name => $1,
                bayer => $2,
                text => $3
                );
            push @$stars, $star;
            $id++;
        }
    }
    return $stars;
}


=item write_csv(fields => \@FIELDS, records => $records, file => $FILE)

Write the records (arrayref of hashrefs) to $FILE with the column order
set by @FIELDS

=cut


sub write_csv {
    my %params = @_;
    
    my $records = $params{records};
    my $fields = $params{fields};
    my $file = $params{file};
    
    my $csv = Text::CSV->new( { binary => 1 } );
    
    open my $fh, ">:encoding(utf8)", $file or die ("Couldn't write to $file: $!");
    
    $csv->print($fh, $fields);
    print $fh "\n";
    
    for my $record ( @$records ) {
        $csv->print($fh, [ map { $record->{$_} } @$fields ]);
        print $fh "\n";
    }
    
    close $fh;

    return 1;
}



=item read_csv(fields => \@FIELDS, file => $FILE)

Read the CSV file $FILE into an arrayref of hashrefs, with column names
set by @FIELDS.  Only reads a line if the first field is a numeric ID.
Returns the records as an arrayref.

=cut


sub read_csv {
    my %params = @_;

    my $file = $params{file};
    my $fields = $params{fields};

    if (!$file ) {
        $log->fatal("No file for read_csv");
        die;
    }

    my $csv = Text::CSV->new;
    $log->info("Reading $file");
    open my $fh, "<:encoding(utf8)", $file || die("$file - $!");

    my $data = [];

    while ( my $row = $csv->getline($fh) ) {
        if( $row->[0] =~ /^\d+$/ ) {
            my $id = $row->[0];
            my $rec = {};
            for my $f ( @$fields ) {
                $rec->{$f} = shift @$row;
            }
            push @$data, $rec;
        }             
    }

    close $fh;

    $log->trace(Dumper({csv => $data}));

    return $data;
}



1;
