package Stellarum::Catalogue;

use strict;

use Stellarum qw(read_csv);

our $log = Log::Log4perl->get_logger('stellarum.catalogue');    

our @FIELDS = qw(
    id hip hd hr gliese bayer name
    ra dec distance pmra pmdec rv
    appmag absmag spectrum colourindex
    x y z vx vy vz
);

sub new {
    my ( $class, %params ) = @_;

    my $self = { file => $params{file} };
    bless $self, $class;

    $self->_load();

    return $self;
}


sub lookup {
    my ( $self, %params ) = @_;

    for my $cat ( 'hip', 'hd' ) {
        if( $params{$cat} && $self->{$cat}{$params{$cat}} ) {
            return $self->{$cat}{$params{$cat}};
        }
    }
    return undef;
}


sub _load {
    my ( $self ) = @_;

    my $rows = read_csv(fields => \@FIELDS, file => $self->{file}) || die;

    $self->{hd} = {};
    $self->{hip} = {};

    for my $row ( @$rows ) {
        if(  $row->{hip} ) {
            $self->{hip}{$row->{hip}} = $row;
        }
        if( $row->{hd} ) {
            $self->{hd}{$row->{hd}} = $row;
        }
    }
}


1;
