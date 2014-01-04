package Stellarum::Wikipedia;

# The wikipedia parsing code

use strict;
use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';
use Data::Dumper;
use WWW::Wikipedia;

use base qw(Exporter);

our @EXPORT_OK = qw(wiki_look);

our $log = Log::Log4perl->get_logger('stellarum.wikipedia');    

our $MAX_REDIRECTS = 5;

our $VALUE_RE = qr/\s*=\s*([^<\|\}]+).*$/ms;

# All of the non-RA/DEC fields to try to grep out of the text

our @FIELDS = qw(
    absmag_v appmag_v class constell dist_ly dist_pc gravity
    luminosity mass metal_fe parallax radial_v radius rotational_velocity
    temperature variable
);

# fields which have multiple-system suffixes

our @SUFFIX_FIELDS = qw(
    absmag_v appmag_v class luminosity radius temperature
);

# The suffixes.  Having surveyed the wikifiles, these are the only values
# for any of the fields, so we can just loop through them to fold them

our @SUFFIXES = qw(1 2 3 _a _b _c);

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

    $values->{ra} = $ra;
    $values->{dec} = $dec;

    my $fields = get_fields($text);

    my $stars = [];
  
    for my $f ( @FIELDS ) {
        
        if( ! $fields->{$f} ) {
            $log->debug("Missing field $f");
        } else {
            my $n = scalar @{$fields->{$f}};
            for my $i ( 0 .. $n - 1 ) {
                $stars->[$i]{$f} = $fields->{$f}[$i];
            }
        }
    }

    $values->{stars} = $stars;

    return $values;
}


sub get_fields {
    my ( $text ) = @_;

    my @lines = split(/\n/, $text);

    $log->trace("grepping " . scalar(@lines) . " lines");
    
    my $all = {};

    for my $line ( @lines ) {
        if( $line =~ /\|\s*(\w*)$VALUE_RE$/ ) {
            my ( $field, $value ) = ( $1, $2 );
            push @{$all->{$field}}, $value;
        }
    }
    
    return collate_fields($all);

}


sub collate_fields {
    my ( $all ) = @_;

    # fold suffix fields

    for my $sf ( @SUFFIX_FIELDS ) {
        if( $all->{$sf} ) {
            my $folded = [ @{$all->{$sf}} ];
            for my $s ( @SUFFIXES ) {
                my $field = $sf . $s;
                if( $all->{$field} ) {
                    push @$folded, @{$all->{$field}};
                    $log->trace("Folded $field => $sf");
                    delete $all->{$field};
                }
            }
            $all->{$sf} = $folded;
        }
    }

    my $collated = {};

    for my $field ( @FIELDS ) {
        if( $all->{$field} ) {
            $collated->{$field} = $all->{$field};
        }
    }

    return $collated;
}



sub dump_fields {
    my ( $fields ) = @_;

    for my $f ( sort keys %$fields ) {
        $log->trace(sprintf('%10s', $f) . ' = ' . join(', ', @{$fields->{$f}}));
    }

}







# This is hairy to cope with variations in Wikipedia star pages

sub parse_angle {
    my %params = @_;

    my $text = $params{text};
    my $coord = $params{coord};

    # Standardise the negative signs in declinations, and remove
    # +

#    $text =~ s/(\N{MINUS SIGN}|\N{EN DASH}|&minus;)/-/g;
#    $text =~ s/\+//g;

    $text = fix_neg($text);

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


sub fix_neg {
    my ( $val ) = @_;

    $val =~ s/(\N{MINUS SIGN}|\N{EN DASH}|&minus;)/-/g;
    $val =~ s/\+//g;

    if( $val =~ /^(.*)(\N{PLUS-MINUS SIGN}|±)/ ) {
        $log->info("Removing plus-minus sign: $val => $1");
        $val = $1;
    }
    return $val;
}

1;
