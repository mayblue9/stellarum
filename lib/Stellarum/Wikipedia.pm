package Stellarum::Wikipedia;

# The wikipedia parsing code

use strict;
use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';
use WWW::Wikipedia;

use base qw(Exporter);

our @EXPORT_OK = qw(wiki_look);

our $log = Log::Log4perl->get_logger('Stellarum::Wikipedia');    

our $MAX_REDIRECTS = 5;



sub wiki_look {
    my %params = @_;

    my $star = $params{star};
    my $dir = $params{dir};

    my $search = $star->{wiki};

    my $values = {};

    $star->{search} = $search;
    if( !$search ) {
        $log->fatal("WARN: no wikisearch for " . Dumper($star));
        die;
    }
    my $result = fetch_wiki(
        search => $search,
        name => $star->{name},
        dir => $dir
        );
    if( $result->{text} ) {
        $values = parse_wiki(wiki => $result->{text});
    }
    return {
        wikistatus => $result->{status},
        %$values
    };
}


sub fetch_wiki {
    my %params = @_;

    my $name = $params{name};
    my $search = $params{search};
    my $dir = $params{dir};

    my $file = star_file(dir => $dir, name => $name);
    my $text = '';
    my $status = '';

    if( -e $file ) {
        open(my $fh, "<:encoding(UTF-8)", $file) || die("Couldn't open cachefile $file: $!");
        local $/;
        $text = <$fh>;
        $status = 'cache';
    } else {
        $text = wiki_search(search => $search);
        if ( $text ) {
            $status = 'found';
            open(my $fh, ">:encoding(UTF-8)", $file) || die("Couldn't open cachefile $file for writing: $!");
            print $fh $text;
            close $fh;
        } else {
            $status = 'not found';
        }
    }
    
    return {
        text => $text,
        status => $status
    }
}


sub star_file {
    my %params = @_;

    return $params{dir} . '/' . $params{name} . '.txt';
}



sub wiki_search {
    my %params = @_;
    
    my $n = 0;

    my $text = undef;
    my $search = $params{search};
    my $wiki = WWW::Wikipedia->new();
    my $result = $wiki->search($search);
    if( $result ) {
        $text = $result->raw();
        while( $text =~ /#REDIRECT\[\[([^\]]+)\]\]/ ) {
            $log->info("Redirecting $search to $1...");
            $n++;
            if( $n > $MAX_REDIRECTS ) {
                $log->warn("Too many redirects for $search");
                return undef;
            }
            $result = $wiki->search($1);
            if( $result ) {
                $text = $result->raw();
            }
        }
    }
    return $text;
}


	


sub parse_wiki {
    my %params = @_;

    my $text = $params{wiki};
    my $values = {};
    
    # remove all {{nowrap|XXX}} markup

    $text =~ s/\{\{nowrap\|([^\}]+)\}\}/$1/g;

    # likewise all &nbsp;s

    $text =~ s/&nbsp;/ /g;
    
    
    # my $ANGLE_RE = qr/([\N{EN DASH}+-]?[0-9]+)\|([0-9]+)\|(\d+\.?\d*)/;
    
    my $VALUE_RE = qr/\s*=\s*([^<\|\}]+).*$/ms;
    
    
    my $ra = parse_angle(text => $text, coord => 'ra');
    my $dec = parse_angle(text => $text, coord => 'dec');
    
    for my $i ( 1, 2, 3 ) {
        if( $ra ) {
            $values->{"ra$i"} = $ra->[$i - 1];
        }
        if( $dec ) {
            $values->{"dec$i"} = $dec->[$i - 1];
        }
    }

    # this processing is done in Stellarum::Star now.
   
#    if( $ra && $dec ) {
#        my @radians = astro_coords($ra, $dec);
#        if( @radians ) {
#            $values->{ra} = $radians[0];
#            $values->{dec} = $radians[1];
#        }
#    }
    
    for my $field ( qw(class mass appmag_v absmag_v) ) {
        if( $text =~ /\|\s*$field$VALUE_RE/ms ) {
            $values->{$field} = $1;
            chomp $values->{$field};
        }
    }
    
    return $values;
}






# This is hairy to cope with variations in Wikipedia star pages

sub parse_angle {
    my %params = @_;

    my $text = $params{text};
    my $coord = $params{coord};

    # Standardise the negative signs in declinations, and remove
    # +

    $text =~ s/(\N{MINUS SIGN}|\N{EN DASH}|&minus;)/-/g;
    $text =~ s/\+//g;

    my $ANGLE_RE = qr/([^|]+)\|([^|]+)\|([^\}]+)\}\}/;

    my $pref = uc($coord);

    my $values = undef;

    if( $text =~ /\{\{$pref\|$ANGLE_RE/s ) {
        $log->trace("$coord pass 1 $1 $2 $3");
	
        $values = [ $1, $2, $3 ];
    } else {
        
        # structured didn't work.
        
        my $NUMBER_RE = qr/-?([\d.]+)([^\d.]+)/;
        
        my $LABEL_RE;
        
        if( $coord eq 'ra' ) {
            $LABEL_RE = qr/(ra|Right ascension)/;
        } else {
            $LABEL_RE = qr/(dec|Declination)/;
        }
        
        if( $text =~ /$LABEL_RE\s*=\s*$NUMBER_RE$NUMBER_RE$NUMBER_RE/ism ) {
            $log->trace("$coord, pass 2 $2 $4 $6");
            my $v1 = $2;
            my $v2 = $4;
            my $v3 = $6;
            
            $values = [ $v1, $v2, $v3 ];
        }
    }
    return $values;
}

1;
