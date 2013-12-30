package Stellarum::Star;

=head1 NAME

Stellarum::Star

=head1 SYNOPSIS

=head1 DESCRIPTION

Represents the parameters and name of a star system. A star can be
binary or multiple.

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

    $self->{log} = Log::Log4perl->get_logger($class);
    
    if( $self->{bayer} =~ /([^\s]*)\s+(\w+[\w\s]*)/ ) {
        
        $self->{constellation} = $2;
        my $number = $1;
        
        if( $number !~ /^[0-9]+$/ ) {
            my $c = substr($number, 0, 1);
            my $greek = greek($c);
            my $suffix = undef;
            if( $greek ) {
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
            }
        }
    }
    return $self;
}


=item update_parameters(parameters => $href)

Takes a hash of raw parameters from Wikipedia and tries to masssage them
into a usable form for the spreadsheet.  Parameters returned are:

=over 4

=item fixme 

=back

=cut







# Convert ra/dec in sexagesimal (HMS) to radians

# ( $ra, $dec ) = astro_coords( [ H, M, S ], [ H, M, S ]);

sub astro_coords {
    my ( $self, $ra_c, $dec_c ) = @_;

    my $ra = join(':', @$ra_c);
    my $dec;
    
    # Because the spreadsheet doesn't allow -0 degrees as a value,
    # we use the string 'neg'.  See for example HEZE.

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
        return ( $r->radians(), $d->radians() );
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
    my ( $self, @bits ) = @_;
   
    return sprintf("%d %d' %d\"", @bits);
}



sub unit_vec {
    my ( $self ) = @_;

    return {
        x => cos($self->{ra}) * cos($self->{dec}),
        y => sin($self->{ra}) * cos($self->{dec}),
        z => sin($self->{dec})
    };
}












=back

=cut



1;
