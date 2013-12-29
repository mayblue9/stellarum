package Stellarum::Words;

=head1 NAME

Stellarum::Words

=head1 SYNOPSIS

=head1 DESCRIPTION

Word lookups and utilities for Stellarum

=cut

use strict;
use base qw(Exporter);

@EXPORT_OK = qw(greek superscript constellation);


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
    'Monocerotis'             => 'Monoceros',
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


sub greek {
    my ( $c ) = @_;

    if( $GREEK{$c} ) {
        return $GREEK{$c};
    } else {
        $logger->warn("Unknown Greek character $c");
        return undef;
    }
}


sub superscript {
    my ( $c ) = @_;

    if( $SUPERSCRIPT{$c} ) {
        return $SUPERSCRIPT{$c};
    } else {
        $logger->warn("Unknown superscript character $c");
        return undef;
    }
}


sub constellation {
    my ( $genitive ) = @_;

    if( $CONSTELLATION{$genitive} ) {
        return $CONSTELLATION{$genitive};
    } else {
        $logger->warn("Unknown genitive constellation $genitive");
        return undef;
    }
}




1;
