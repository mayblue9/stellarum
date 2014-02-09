package Stellarum::Star;

=head1 NAME

Stellarum::Star

=head1 SYNOPSIS

=head1 DESCRIPTION

Represents the parameters and name of a star system. 

=cut
use strict;


use lib $ENV{STELLARUM_LIB};


use utf8;
use Encode qw(encode decode);
use feature 'unicode_strings';
use charnames ':full';

use Data::Dumper;
use Astro::Coords;
use Log::Log4perl;

use Stellarum::Words qw(greek constellation superscript);

# our @FIELDS = qw(
#     absmag_v appmag_v class constell dist_ly dist_pc gravity
#     luminosity mass metal_fe parallax radial_v radius rotational_velocity
#     temperature variable
# );

my $CLASS_RE = qr/^[CMKFGOBAPWS]$/;
my $DEFAULT_CLASS = 'A';

our @FIELDS = qw(appmag absmag distance spectrum colourindex);

our $log = Log::Log4perl->get_logger('stellarum.star');    



=head1 METHODS

=over 4

=item new(%params)

Create a new star from a tweet.  Parameters:

=over 4

=item bayer - Bayer designation

=item name 

=item text - the description in the tweet

=item id - an index number

=cut

sub new {
    my ( $class, %params) = @_;

    my $self = {
        bayer => $params{bayer},
        name => $params{name},
        text => $params{text},
        html => $params{bayer},
        wiki => $params{bayer},
        id => $params{id}
    };

    bless $self, $class;

    $self->{log} = Log::Log4perl->get_logger('stellarum.star');
    
    $self->{log}->trace("New star $self->{name}");

    if( $self->{bayer} =~ /([^\s]*)\s+(\w+[\w\s]*)/ ) {
        $self->{constellation} = $2;
        my $number = $1;
        
        if( $number !~ /^[0-9]+$/ ) {
            my $c = substr($number, 0, 1);
            my $greek = greek($c);
            my $suffix = undef;
            if( $greek ) {
                $self->{log}->trace("Greek match for '$c' - '$greek'");
                if( length($number) > 1 ) {
                    my $super = substr($number, -1, 1);
                    $suffix = superscript($super);
                }
                $self->{wiki} = ucfirst($greek) . $suffix;
                $self->{wiki} .= ' ' . $self->{constellation};
                $self->{html} = '&' . $greek . ';';
                if( $suffix ) {
                    $self->{html} .= "<super>$suffix</super>";
                }
                $self->{html} .= " $self->{constellation}";
            } else {
                $self->{log}->warn("$self->{id} $self->{name} No greek match for '$c'");
            }
        }
    } else {
        $self->{log}->warn("$self->{id} $self->{name} Mismatch bayer");
    }
    return $self;
}


=item set(parameters => $href)

Takes a hash of raw parameters from Wikipedia and tries to masssage them
into a usable form for the spreadsheet.  Parameters returned are:

=over 4

=item fixme 

=back

=cut


sub set { 
    my ( $self, %params ) = @_;

    my $p = $params{parameters};

    if( $p->{ra} && $p->{dec} ) {
        $self->astro_coords(ra => $p->{ra}, dec => $p->{dec});
    }

    $self->{wikistatus} = $p->{wikistatus};

    for my $field ( @FIELDS ) {
        $self->{$field} = $p->{$field};
    }


    my $hascat = 'no';
    for my $cat ( qw(Hipparcos Draper BrightStar) ) {
        $self->{$cat} = $p->{catalogues}{$cat};
        if( $self->{$cat} ) {
            $hascat = 'yes';
        }
    }
    $self->{hascat} = $hascat;

}




=item astro_coords(ra => [ H, M, S ], dec => [H, M, S]);

Convert ra/dec in sexagesimal (HMS) to radians and store it as the
stars's ra and dec.

Because the spreadsheet doesn't allow -0 degrees as a value, we use
the string 'neg'.  See for example HEZE.

=cut


sub astro_coords {
    my ( $self, %params ) = @_;

    my $ra_c = $params{ra};
    my $dec_c = $params{dec};

    my $ra = join(':', @$ra_c);
    my $dec;
    
    if( $dec_c->[0] eq 'neg' ) {
        $self->{log}->debug("Negative zero in declination");
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

        $self->{ra} = $r->radians();
        $self->{dec} = $d->radians();

        return ( $self->{ra}, $self->{dec} );

    } else {
        $self->{log}->warn("Couldn't construct Astro::Coords object");
        eval {
            my $c = substr($dec->[0], 0, 1);
            $self->{log}->warn("Initial character of dec: $c");
            $self->{log}->warn("ord = " . ord($c));
            $self->{log}->warn("viacode = " . charnames::viacode(ord($c)));
        };
        if( $@ ) {
            $self->{log}->error("Couldn't even debug bad Astro::Coords");
        }
        return undef;
    }
}




    






sub dispcoords {
    my ( $self ) = @_;

    my @co = ();

    for my $ax ( 'ra', 'dec' ) {
        push @co, $ax . ' ' . sprintf(
            "%d %d' %d\"", 
            map { $self->{"$ax$_"} } (1, 2, 3)
            );
    }
    return join(' ', @co);
}



sub unit_vec {
    my ( $self ) = @_;

    return {
        x => cos($self->{ra}) * cos($self->{dec}),
        y => sin($self->{ra}) * cos($self->{dec}),
        z => sin($self->{dec})
    };
}


=item json()

Return a hashref for the stars.json file based on this star's parameters

=cut

sub json {
    my ( $self ) = @_;

    my $class = uc(substr($self->{spectrum}, 0, 1));
    if ( $class !~ /$CLASS_RE/ ) {
        $log->warn("Bad class $class for $self->{id} $self->{name}, forced A");
        $class = $DEFAULT_CLASS;
    }
    my $coords = $self->dispcoords();
    
    my $const = $Stellarum::Words::CONSTELLATIONS{$self->{constellation}};

    if ( ! $const )  {
        $log->warn(
            "$self->{id} $self->{name}unknown constellation $self->{constellation}"
            );
    }
    
    
    my $json = {
        id => $self->{id} + 0,
        name => $self->{name},
        designation => $self->{bayer},
        constellation => $const,
        wiki => $self->{wiki},
        html => $self->{html},
        magnitude => $self->{appmag},
        ra => $self->{ra} + 0,
        dec => $self->{dec} + 0,
        coords => $coords,
        vector => $self->unit_vec(),
        text => $self->{text},
        spectrum => $self->{spectrum},
        distance => $self->{distance},
        absmagnitude => $self->{absmag},
        colourindex => $self->{colourindex},
        class => $class
    };
        
    return $json;
}









=back

=cut



1;
