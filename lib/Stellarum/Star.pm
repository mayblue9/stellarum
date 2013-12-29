package Stellarum::Star

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

use Stellarum::Words;

=head1 METHODS

=over 4

=item new(%params)

Create a new star, optionally setting the parameters.

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
    
    if( $self->{bayer} =~ /([^\s]*)\s+(\w+[\w\s]*)/ ) {
        
        $self->{constellation} = $2;
        my $number = $1;
        
        if( $number !~ /^[0-9]+$/ ) {
            my $c = substr($number, 0, 1);
            my $greek = undef;
            my $suffix = undef;
            if( greek_{$c} ) {
                $greek = $GREEK{$c};
                if( length($number) > 1 ) {
                    my $super = substr($number, -1, 1);
                    $suffix = $SUPERSCRIPT{$super};
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
