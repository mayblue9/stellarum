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

my $MAX_STARS = undef;

my $MAX_REDIRECTS = 5;

my $FILEDIR = './Wikifiles/';

my @FIELDS = qw(
    id name designation greek constellation
    search wikistatus
    ra1 ra2 ra3 dec1 dec2 dec3 ra dec
    appmag_v class mass radius
    text
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



my $INFILE = 'fsvo.js';
my $MANUALSTARS = 'Manual_stars.csv';

my $CSVOUT = 'stars.csv';
my $JSONOUT = 'stars.js';


open(JSONFILE, "<$INFILE") || die("Couldn't open $INFILE $!");
my $json;

{
    local $/;

    $json = <JSONFILE>;
}

my $data = decode_json($json);

my $stars = read_json_stars(tweets => $data->{tweets});
my $mstars = read_csv(file => $MANUALSTARS, fields => \@FIELDS);

print Dumper({manual => $mstars});

die;

my @nowiki = map { $_->{wiki} ? () : $_ } @$stars;

if( @nowiki ) {
    print "Empty wiki searches:\n" . Dumper(\@nowiki) . "\n";
    die;
}

my $n = 0;
for my $star ( @$stars ) {
    my $wiki = wiki_look(star => $star);
    for my $field ( keys %$wiki ) {
	$star->{$field} = $wiki->{$field};
    } 
    print "$star->{name} $wiki->{wikistatus}\n";
    if( $MAX_STARS && $n > $MAX_STARS ) {
	last;
    }
    $n++;
}

write_csv(stars => $stars);

write_json(stars => $stars);


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

    if( my $xrefs = get_xrefs(text => $text) ) {
	$star->{xrefs} = $xrefs;
	print "XREFS $name: " . join(' ', @$xrefs) . "\n";
    }
    
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

# sub char2greekletter {
#     my %params = @_;

#     my $char = $params{char};

#     return '' if $char =~ /^[0-9]+$/;

#     my $c = substr($char, 0, 1);
#     if( $GREEK{$c} ) {
#  	if( length($char) > 1 ) {
# 	    my $super = substr($char, -1, 1);
# 	    return $GREEK{$c} . $SUPERSCRIPT{$super};
# 	} else {
# 	    return $GREEK{$c};
# 	}
#     } else {
# 	return '';
#     }
# }


sub get_xrefs { 
    my %params = @_;

    my $text = $params{text};

    my $xrefs = [];

    while( $text =~ m/([A-Z][A-Z ]+)/g ) {
	push @$xrefs, $1;
    }
    
    if( @$xrefs ) { 
	return $xrefs;
    } else {
	return undef;
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
	print "WARN: no wikisearch for " . Dumper($star);
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
	    print "Redirecting $search to $1...\n";
	    $n++;
	    if( $n > $MAX_REDIRECTS ) {
		print "Too many redirects.\n";
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
	my $coords = Astro::Coords->new(
	    name => 'test',
	    ra => join(':', @$ra),
	    dec => join(':', @$dec),
	    type => 'J2000',
	    units => 'sexagesimal'
	    );
	
	if( $coords ) {
	    my ( $r, $d ) = $coords->radec();
	    $values->{ra} = $r->radians();
	    $values->{dec} = $d->radians();
	} else {
	    print "Couldn't construct Astro::Coords object\n";
	    my $c = substr($dec->[0], 0, 1);
	    print "Initial character of dec: $c\n";
	    print "ord = " . ord($c) . "\n";
	    print "viacode = " . charnames::viacode(ord($c)) . "\n";
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
	print "$coord pass 1 $1 $2 $3\n";
	
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
	    print "$coord, pass 2 $2 $4 $6\n";
	    my $v1 = $2;
	    my $v2 = $4;
	    my $v3 = $6;

	    $values = [ $v1, $v2, $v3 ];
	}
    }
    return $values;
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

    my $data = {};

    while ( my $row = $csv->getline($fh ) ) {
        print join(' ', @$row) . "\n";
        if( $row->[1] =~ /^[A-Z]+/ ) {
            my $n = $row->[1];
            $data->{$n} = {};
            for my $f ( @$fields ) {
                $data->{$n}{$f} = shift @$row;
            }
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

    for my $star ( @$stars ) {
        if ( defined $star->{ra} ) {
            my $class = uc(substr($star->{class}, 0, 1));
            if ( $class !~ /^[CMKFGOBA]$/ ) {
                print "Bad class $class for $star->{name}, forced A\n";
                $class = 'A';
            } else {
                print "good class $class for $star->{name}\n";
            }
            push @$data, {
                id => $star->{id},
                name => $star->{name},
                designation => $star->{bayer},
                wiki => $star->{wiki},
                html => $star->{html},
                magnitude => int($star->{appmag_v}),
                ra => $star->{ra} + 0,
                dec => $star->{dec} + 0,
                vector => unit_vec(star => $star),
                text => $star->{text},
                class => $class
            };
        }
    }
    
    
    my $text = $json->pretty->encode($data);
    
    open(my $fh, ">:encoding(utf8)", $JSONOUT) || die("Couldn't write to $JSONOUT: $!");

    print $fh "var stars = $text";
    close $fh;
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
