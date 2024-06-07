use v6.d;

# The original code was taken from Brian Duggan's "Geo::Base",
# who in turn had taken it from RosettaCode.
# See:
# [BD1] Brian Duggan, "Geo::Base", (2024), Github/bduggan.
#       URL: https://github.com/bduggan/raku-geo-basic/blob/main/lib/Geo/Basic.rakumod

# B. Duggan's note in [BD1]:
# see https://rosettacode.org/wiki/Geohash#Roll_your_own
# changes: https://rosettacode.org/w/index.php?title=Geohash&diff=300667&oldid=300666
# Credit: https://rosettacode.org/wiki/User:Thundergnat
#   "Any code which I have submitted to Rosettacode may be used under the Unlicense."
#   https://choosealicense.com/licenses/unlicense/

# Ideally, after I localize the geohash code for my needs I will submit
# pull request(s) to "Geo::Base", [BD1].

# ==============================================================================
unit module Data::Geographics::GeoHash;

my @Geo32 = <0 1 2 3 4 5 6 7 8 9 b c d e f g h j k m n p q r s t u v w x y z>;

#| Geohash alphabet
our sub geohash-alphabet() { @Geo32};

#| Encode a latitude and longitude into a geohash
our sub geohash-encode ( Rat(Real) :lat(:$latitude), Rat(Real) :lon(:$longitude), Int :$precision = 9 ) is export {
    my @coord = $latitude, $longitude;
    my @range = [-90, 90], [-180, 180];
    my $which = 1;
    my $value = '';
    while $value.chars < $precision * 5 {
        my $mid = @range[$which].sum / 2;
        $value ~= my $upper = +(@coord[$which] > $mid);
        @range[$which][not $upper] = $mid;
        $which = not $which;
    }
    @Geo32[$value.comb(5)».parse-base(2)].join;
}

#| Decode a geohash into a latitude and longitude
our sub geohash-decode ( Str $geo --> Hash ) is export {
    my @range = [-90, 90], [-180, 180];
    my $which = 1;
    my %Geo32 = @Geo32.antipairs;
    for %Geo32{$geo.comb}».fmt('%05b').join.comb {
        @range[$which][$_] = @range[$which].sum / 2;
        $which = not $which;
    }
    my @res = @range >>*>> -1;
    my ($lat-min, $lat-max) = @res[0];
    my ($lon-min, $lon-max) = @res[1];

    return %(
        latitude => %( min => $lat-min, max => $lat-max),
        longitude => %( min => $lon-min, max => $lon-max )
    );
}

our sub neighbor(Str $geo, $dx, $dy) {
    with geohash-decode($geo) {
        my $latitude = ( .<latitude><max> + .<latitude><min> ) / 2 + $dx * (.<latitude><max> - .<latitude><min>);
        my $longitude = ( .<longitude><max> + .<longitude><min> ) / 2 + $dy * (.<longitude><max> - .<longitude><min>);
        geohash-encode(:$latitude, :$longitude, precision => $geo.chars);
    }
}

# See https://eugene-eeo.github.io/blog/geohashing.html
# #| Find the neighbors of a geohash
our sub geohash-neighbors( Str $geo ) is export {
    my @n;
    for <-1 0 1> X <-1 0 1> -> ($dx, $dy) {
        next if $dx == $dy == 0;
        @n.push: neighbor($geo, $dx, $dy);
    }
    @n
}