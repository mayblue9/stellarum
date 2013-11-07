#!/usr/bin/perl

# Read the JSON archive of FSVO tweets for stars, and look them up in
# Wikipedia to get coordinates and other metadata

use strict;
use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';

use JSON;
use Data::Dumper;
use Text::CSV;
use WWW::Wikipedia;
use Astro::Coords;
use Log::Log4perl;

my $LOGCONF = './log4j.properties';

my $MAX_STARS = undef;

my $MAX_REDIRECTS = 5;

my $USE_WIKI = 0;

my $CLASS_RE = qr/^[CMKFGOBAPW]$/;
my $DEFAULT_CLASS = 'A';

my $FILEDIR = './Wikifiles/';

my @FIELDS = qw(
    id name designation greek constellation
    search wikistatus
    ra1 ra2 ra3 dec1 dec2 dec3 ra dec
    appmag_v class mass radius
    text xrefs
);

my %GREEK = (
    'α' => 'alpha',
    'β' => 'beta',
    'γ' => 'gamma',
    'δ' => 'delta',
    'ε' => 'epsilon',	
    'ζ' => 'zeta',
    'η' => 'eta',	
    'θ' => 'theta',	
    'ι' => 'iota',	
    'κ' => 'kappa',	
    'λ' => 'lambda',	
    'μ' => 'mu',
    'ν' => 'nu',	
    'ξ' => 'xi',	
    'ο' => 'omicron',	
    'π' => 'pi',
    'ρ' => 'rho',	
    'σ' => 'sigma',	
    'τ' => 'tau',	
    'υ' => 'upsilon',	
    'φ' => 'phi',
    'χ' => 'chi',	
    'ψ' => 'psi',	
    'ω' => 'omega'
);

my %SUPERSCRIPT = (
    '¹' => 1,
    '²' => 2,
    '³' => 3,
 );

# Convert constellations from genitive to nominative for the
# filter control

my %CONSTELLATIONS = (
    'Andromedae'              => 'Andromeda',
    'Aquarii'                 => 'Aquarius',
    'Aquilae'                 => 'Aquila',
    'Arae'                    => 'Ara',
    'Arietis'                 => 'Aries',
    'Aurigae'                 => 'Auriga',
    'Boötis'                  => 'Boötes',
    'Cancri'                  => 'Cancer',
    'Canis Majoris'           => 'Canis Major',
    'Canis Minoris'           => 'Canis Minor',
    'Canum Venaticorum'       => 'Canes Venatici',
    'Capricorni'              => 'Capricornus',
    'Carinae'                 => 'Carina',
    'Cassiopeiae'             => 'Cassiopeia',
    'Centauri'                => 'Centaurus',
    'Cephei'                  => 'Cepheus',
    'Ceti'                    => 'Cetus',
    'Columbae'                => 'Columba',
    'Comae Berenices'         => 'Coma Berinices',
    'Coronae Australis'       => 'Corona Australis',
    'Coronae Borealis'        => 'Corona Borealis',
    'Corvi'                   => 'Corvus',
    'Crateris'                => 'Crater',
    'Crucis'                  => 'Crux',
    'Cygni'                   => 'Cygnus',
    'Delphini'                => 'Delphinus',
    'Draconis'                => 'Draco',
    'Equulei',                => 'Equueleus',
    'Eridani',                => 'Eridanus',
    'Fornacis',               => 'Fornax',
    'Geminorum',              => 'Gemini',
    'Gruis',                  => 'Grus',
    'Herculis'                => 'Hercules',
    'Hydrae',                 => 'Hydra',
    'Hydri',                  => 'Hydrus',
    'Indi',                   => 'Indus',
    'Leonis',                 => 'Leo',
    'Leonis Minoris',         => 'Leo Minor',
    'Leporis'                 => 'Lepus',
    'Librae'                  => 'Libra',
    'Lyncis'                  => 'Lynx',
    'Lyrae'                   => 'Lyra',
    'Microscopii'             => 'Microscopium',
    'Muscae'                  => 'Musca',
    'Octantis',               => 'Octans',
    'Ophiuchi',               => 'Ophiuchus',
    'Orionis',                => 'Orion',
    'Pavonis',                => 'Pavo',
    'Pegasi',                 => 'Pegasus',
    'Persei',                 => 'Perseus',
    'Phoenicis'               => 'Phoenix',
    'Piscis Austrini'         => 'Piscis Austrinus',
    'Piscium'                 => 'Pisces',
    'Puppis'                  => 'Puppis',
    'Sagittae',               => 'Sagitta',
    'Sagittarii'              => 'Sagittarius',
    'Scorpii'                 => 'Scorpius',
    'Serpentis',              => 'Serpens',
    'Tauri'                   => 'Taurus',
    'Trianguli'               => 'Triangulum',
    'Trianguli Australis'     => 'Triangulum Australe',
    'Ursae Majoris'           => 'Ursa Major',
    'Ursae Minoris'           => 'Ursa Minor',
    'Velorum',                => 'Vela',
    'Virginis',               => 'Virgo',
    'Vulpeculae',             => 'Vulpecula'
);

# Manual overrides for the crossreferences which can't be done manually




Log::Log4perl::init($LOGCONF);

my $log = Log::Log4perl->get_logger('stellarum');

my $INFILE = 'fsvo.js';
my $PARAMETERS = 'star_parameters.csv';

my $CSVOUT = 'stars.csv';
my $JSONOUT = 'stars.js';

my $EXTRA_JSON = <<EOJS;

var starNames = [];

for (var i = 0; i < stars.length; i++ ) {
    starNames.push(stars[i].name);
}

var constNames = constellations.keys()
EOJS

open(JSONFILE, "<$INFILE") || die("Couldn't open $INFILE $!");
my $json;

{
    local $/;

    $json = <JSONFILE>;
}

my $data = decode_json($json);

my $stars = read_json_stars(tweets => $data->{tweets});

my $parameters = read_csv(file => $PARAMETERS, fields => \@FIELDS);

my @nowiki = map { $_->{wiki} ? () : $_ } @$stars;

if( @nowiki ) {
    $log->fatal("Empty wiki searches:\n" . Dumper(\@nowiki) . "\n");
    die;
}

my $outstars = [];

if( $USE_WIKI ) {
    $log->info("Getting star data from Wiki/wikicache");
    my $n = 0;

    for my $star ( @$stars ) {
        my $wiki = wiki_look(star => $star);
        for my $field ( keys %$wiki ) {
            $star->{$field} = $wiki->{$field};
        } 
        $log->debug("$star->{name} $wiki->{wikistatus}");
        if( $MAX_STARS && $n > $MAX_STARS ) {
            $log->info("Reached MAX_STARS $MAX_STARS");
            last;
        }
        $n++;
    }
    $outstars = $stars;
} else {
    $log->info("Getting star data from spreadsheet: $PARAMETERS");

    my @fields = qw(
       constellation ra1 ra2 ra3 dec1 dec2 dec3 ra dec appmag_v class
       text xrefs
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
            if( $star->{name} ne $csvstar->{name} ) {
                die "$id $star->{name} MISMATCH $csvstar->{name}\n";
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

}

add_xrefs(stars => $outstars);

write_csv(stars => $outstars);

write_json(stars => $outstars);


sub read_json_stars {
    my %params = @_;

    my $stars = [];
    my $id = 1;
    
    my $tweets = $params{tweets};
    
    for my $tweet ( @$tweets ) {
        my $text = $tweet->{text};
        
        if( $text =~ /^([A-Z\s]+)\s+\(([^),]*)\)\s+(.*)/ ) {
            
            my $star = parse_tweet(
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

sub parse_tweet {
    my %params = @_;

    my $name = $params{name};
    my $bayer = $params{bayer};
    my $text = $params{text};
    my $id = $params{id};

    my $star = {
        bayer => $bayer,
        name => $name,
        text => $text,
        html => $bayer,
        wiki => $bayer,
        id => $id
    };
    
    if( $bayer =~ /([^\s]*)\s+(\w+[\w\s]*)/ ) {
        
        $star->{constellation} = $2;
        
        my $number = $1;
        
        if( $number !~ /^[0-9]+$/ ) {
            my $c = substr($number, 0, 1);
            my $greek = undef;
            my $suffix = undef;
            if( $GREEK{$c} ) {
                $greek = $GREEK{$c};
                if( length($number) > 1 ) {
                    my $super = substr($number, -1, 1);
                    $suffix = $SUPERSCRIPT{$super};
                }
                $star->{wiki} = ucfirst($greek) . $suffix;
                $star->{wiki} .= ' ' . $star->{constellation};
                $star->{html} = '&' . $greek . ';';
                if( $suffix ) {
                    $star->{html} .= "<super>$suffix</super>";
                }
                $star->{html} .= " $star->{constellation}";
            }
        }
    }
    return $star;
}




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





sub wiki_look {
    my %params = @_;

    my $star = $params{star};

    my $search = $star->{wiki};

    # if( $star->{greek_full} ) {
    # 	$search = join(' ', ucfirst($star->{greek_full}), $star->{constellation});
    # }

    my $values = {};

    $star->{search} = $search;
    if( !$search ) {
        $log->fatal("WARN: no wikisearch for " . Dumper($star));
        die;
    }
    my $result = fetch_wiki(search => $search, name => $star->{name});
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

    my $file = star_file(name => $name);
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
    
    if( $ra && $dec ) {
        my @radians = astro_coords($ra, $dec);
        if( @radians ) {
            $values->{ra} = $radians[0];
            $values->{dec} = $radians[1];
        }
    }
    
    for my $field ( qw(class mass appmag_v) ) {
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
        $log->debug("$coord pass 1 $1 $2 $3");
	
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
            $log->debug("$coord, pass 2 $2 $4 $6");
            my $v1 = $2;
            my $v2 = $4;
            my $v3 = $6;
            
            $values = [ $v1, $v2, $v3 ];
        }
    }
    return $values;
}


# Convert ra/dec in sexagesimal (HMS) to radians

# ( $ra, $dec ) = astro_coords( [ H, M, S ], [ H, M, S ]);

sub astro_coords {
    my ( $ra_c, $dec_c ) = @_;

    my $ra = join(':', @$ra_c);
    my $dec;
    
    # Because the spreadsheet doesn't allow -0 degrees as a value,
    # we use the string 'neg'.  See for example HEZE.

    if( $dec_c->[0] eq 'neg' ) {
        $log->debug("Negative zero in declination");
        $dec = join(':', '-0', $dec_c->[1], $dec_c->[2]);
    } else {
        $dec = join(':', @$dec_c);
    }
    
    my $coords = Astro::Coords->new(
        name => 'test',
        ra => $ra,
        dec => $dec,
        type => 'J2000',
        units => 'sexagesimal'
        );
    
    if( $coords ) {
        my ( $r, $d ) = $coords->radec();
        return ( $r->radians(), $d->radians() );
    } else {
        $log->warn("Couldn't construct Astro::Coords object");
        my $c = substr($dec->[0], 0, 1);
        $log->warn("Initial character of dec: $c");
        $log->warn("ord = " . ord($c));
        $log->warn("viacode = " . charnames::viacode(ord($c)));
        return undef;
    }
}



sub star_file {
    my %params = @_;

    return $FILEDIR . '/' . $params{name} . '.txt';
}

    


sub write_csv {
    my %params = @_;
    
    my $stars = $params{stars};
    
    my $csv = Text::CSV->new( { binary => 1 } );
    
    open my $fh, ">:encoding(utf8)", $CSVOUT or die ("Couldn't write $CSVOUT: $!");
    
    $csv->print($fh, \@FIELDS);
    print $fh "\n";
    
    for my $star ( @$stars ) {
        $csv->print($fh, [ map { $star->{$_} } @FIELDS ]);
        print $fh "\n";
    }
    
    close $fh;
}


sub read_csv {
    my %params = @_;

    my $file = $params{file};
    my $fields = $params{fields};

    my $csv = Text::CSV->new;

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

    return $data;
}




sub write_json {
    my %params = @_;

    my $stars = $params{stars};

    my $json = JSON->new();

    my $data = [];
    my $constellations = {};


    for my $star ( @$stars ) {
        if ( defined $star->{ra} ) {
            my $class = uc(substr($star->{class}, 0, 1));
            if ( $class !~ /$CLASS_RE/ ) {
                $log->warn("Bad class $class for $star->{id} $star->{name}, forced A");
                $class = $DEFAULT_CLASS;
            }
            
            my $coords = "RA " . dispcoords($star->{ra1}, $star->{ra2}, $star->{ra3});
            $coords .= " Dec " . dispcoords($star->{dec1}, $star->{dec2}, $star->{dec3});
            my $const = $CONSTELLATIONS{$star->{constellation}} || do {
                $log->warn("$star->{id} $star->{name} - unknown constellation $star->{constellation}");
            };
            push @$data, {
                id => $star->{id},
                name => $star->{name},
                designation => $star->{bayer},
                constellation => $const,
                wiki => $star->{wiki},
                html => $star->{html},
                magnitude => $star->{appmag_v},
                ra => $star->{ra} + 0,
                dec => $star->{dec} + 0,
                coords => $coords,
                vector => unit_vec(star => $star),
                text => $star->{text},
                class => $class
            };

            if( $const ) {
                push @{$constellations->{$const}}, $star->{id}
            }
            
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


sub dispcoords {
    my @bits = @_;
   
    return sprintf("%d %d' %d\"", @bits);
}



sub unit_vec {
    my %params = @_;

    my $star = $params{star};

    return {
	x => cos($star->{ra}) * cos($star->{dec}),
	y => sin($star->{ra}) * cos($star->{dec}),
	z => sin($star->{dec})
    };
}
