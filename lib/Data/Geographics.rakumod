unit module Data::Geographics;

use JSON::Fast;
use Data::Geographics::GeoHash;

#============================================================
my %country-records;
my @country-record-fields;

#| Ingest the country data database.
sub ingest-country-data() is export {
    # It is expected that resource file "prompts.json" is an array of hashes.
    %country-records = from-json(slurp(%?RESOURCES<aCountryRecords.json>));

    @country-record-fields = %country-records.values.head.keys.sort;

    return %(:%country-records, :@country-record-fields);
}

#============================================================

sub location-link($lat, $lon, UInt :$zoom = 12) is export {
    return "http://maps.google.com/maps?q=$lat,$lon&z=$zoom&t=h";
}

#============================================================
my @city-records;
my @city-record-fields;

#| Ingest the city data database.
sub ingest-city-data(:$sep is copy = Whatever) is export {

    #| City data files
    my $cityDataFileNames = q:to/END/;
        dfBotswanaCityRecords.csv
        dfBulgariaCityRecords.csv
        dfCanadaCityRecords.csv
        dfGermanyCityRecords.csv
        dfHungaryCityRecords.csv
        dfRussiaCityRecords.csv
        dfSpainCityRecords.csv
        dfUkraineCityRecords.csv
        dfUnitedStatesCityRecords.csv
    END

    if $sep.isa(Whatever) { $sep = / <?after \S> ',' <?before \S> /; }
    die 'The argument $sep is expected to be a string, a regex, or Whatever.'
    unless $sep ~~ Str:D || $sep ~~ Regex;

    my @fileNames = $cityDataFileNames.lines>>.trim;

    # Read city records from files
    @city-records = [];
    @city-record-fields = [];
    for @fileNames -> $fileName {
        # It 7-10 faster to use this ad-hoc code than the standard Text::CSV workflow.
        # But some tags might have commas (i.e. the separator) in them.
        my $fileHandle = %?RESOURCES{$fileName}.IO;
        my Str @records = $fileHandle.lines;
        my @colNames = @records[0].split($sep).map({ $_.subst(/ ^ '"' | '"' $/):g }).Array;
        my @res = @records[1 .. *- 1].map({ (@colNames Z=> $_.split($sep).map({ $_.subst(/ ^ '"' | '"' $/):g })).Hash }).Array;
        @city-record-fields = [|@city-record-fields, |@colNames].unique.Array;
        @city-records.append(@res);
    }

    # Simple sanity check
    if @city-record-fields.sort !eqv ["Country", "State", "City", "Population", "Latitude", "Longitude", "Elevation"]
            .sort {
        note 'Unexpected column names.';
    }

    # Convert numeric fields
    my &nconv = -> Str $n { $n ~~ Str:D && $n.lc ne 'null' ?? ( $n.ends-with('.') ?? ($n ~ '0').Numeric !! $n.subst('.e', '.').Numeric ) !! 'null' };
    @city-records =
            @city-records.map({
                my %h = $_.Hash , %( Population => &nconv($_<Population>),
                                     Latitude => &nconv($_<Latitude>),
                                     Longitude => &nconv($_<Longitude>),
                                     Elevation => &nconv($_<Elevation>));
                %h
            });

    # Add location link
    @city-records = @city-records.map({ my %h = $_.Hash , %(LocationLink => location-link($_<Latitude>, $_<Longitude>) ); %h });
    @city-record-fields.push('LocationLink');

    # Split city and country names over capital letters.
    # Temporary: this is not a completely reliable way of getting the real geographical names.
    my &nsplit = -> $n { $n ~~ Str:D ?? $n.subst(/ <?after <:Ll>> (<:Lu>) <?before <:Ll>> /, { ' ' ~ $0.Str }) !! $n };
    @city-records = @city-records.map({ my %h = $_.Hash , %( City => &nsplit($_<City>) ); %h });

    # Add IDs
    @city-records  = @city-records.map({ my %h = $_.Hash , %('ID', make-geographics-id( |$_<Country State City>, sep=>'.' )); %h });

    # Result
    return %(:@city-records, :@city-record-fields);
}

#============================================================
proto sub country-data(|) is export {*}

multi sub country-data($spec = Whatever, $fields is copy = Whatever) {
    return country-data($spec, :$fields);
}

multi sub country-data($spec = Whatever, :$fields is copy = Whatever) {
    # Ingest country data if needed
    if !%country-records { ingest-country-data(); }

    # Retrieve country data by spec
    my %res = do given $spec {
        when Whatever {
            %country-records.clone;
        }
        when $_ ~~ Str:D && $_.lc ∈ <properties fields> {
            return @country-record-fields;
        }
        when $_ ~~ Str:D || $_ ~~ Regex {
            %country-records.grep({ $_.key ~~ $spec }).Hash;
        }
        default {
            die 'The first argument is expected to be a string, a regex, or Whatever.';
        }
    }

    # Return result with required properties
    return do given $fields {
        when Whatever { %res }
        when ($_ ~~ Str:D) && ($_ ∈ @country-record-fields) {
            %res.map({ $_.key => $_.value{$fields} })
        }
        when ($_ ~~ Positional) && ($_.all ~~ Str:D) && ($_ (-) @country-record-fields).elems == 0 {
            %res.map({ $_.key => $_.value.grep({ $_.key ∈ $fields }).Hash }).Hash
        }
        default {
            die "The second argument is expected to a string, a list of strings, or Whatever."
        }
    }
}

#============================================================
#| C<city-data> function provides information about cities based on the provided specifications.
#| C<$spec> -- can be a string, a regex, a list of strings or regexes, or Whatever. It is used to filter the city records.
#| C<$fields> -- can be a string, a list of strings, or Whatever. It is used to select the properties of the city records to return.
#| C<:$nested> -- named argument is a boolean value that determines whether the result should be nested by country, state, and city.
proto sub city-data(|) is export {*}

multi sub city-data($spec, $fields = Whatever, Bool :$nested = False) {
    return city-data($spec, :$fields, :$nested);
}

multi sub city-data($spec, :$fields is copy = Whatever, Bool :$nested = False) {

    # Ingest city data if needed
    if !@city-records { ingest-city-data(); }

    # Filter city records
    my @res;
    given $spec {
        when $_ ~~ Str:D && $_.lc ∈ <properties fields> {
            return @city-record-fields;
        }

        when Str:D {
            @res = @city-records.grep({ $_<City> ~~ $spec });
        }

        when Regex {
            @res = @city-records.grep({ $_<City> ~~ $spec });
        }

        when $_ ~~ Positional && ([&&] $_.map({ $_.isa(Whatever) })) {
            @res = @city-records
        }

        when $_ ~~ Positional && $_.elems == 3 {
            @res = @city-records.grep({
                ($spec[0].isa(Whatever) ?? True !! $_<Country> ~~ $spec[0]) &&
                        ($spec[1].isa(Whatever) ?? True !! $_<State> ~~ $spec[1]) &&
                        ($spec[2].isa(Whatever) ?? True !! $_<City> ~~ $spec[2])
            })
        }

        when $_ ~~ Positional && $_.elems == 2 {
            @res = @city-records.grep({
                ($spec[1].isa(Whatever) ?? True !! $_<City> ~~ $spec[0]) &&
                        (($spec[1].isa(Whatever) ?? False !! $_<State> ~~ $spec[0]) ||
                                ($spec[2].isa(Whatever) ?? False !! $_<City> ~~ $spec[0]))
            })
        }

        default {
            die "The first argument is expected to be a string, a regex, a list of strings or regexes, or Whatever"
        }
    }

    # Enhance
    if $fields ~~ Str:D { $fields = [$fields,]; }

    # Properties / fields validation function
    my &valid-props = { ($_ ~~ Positional) && ($_.all ~~ Str:D) && ($_ (-) @city-record-fields).elems == 0 };

    # Return result with required properties

    my $errMsg = "The second argument is expected to a string, a list of strings, or Whatever.";

    if $nested {
        my $nFields = do given $fields {
            when Whatever { @city-record-fields }
            when &valid-props($_) { $fields }
            default { die $errMsg; }
        }

        my %countryStateCity = @res
                    .classify(*<Country>)
                    .map({ $_.key => $_.value.classify(*<State>)
                    .map({ $_.key => $_.value.map({ $_<City> => $_.grep({ $_.key ∈ $nFields }).Hash }).Hash }).Hash });

        return %countryStateCity;

    } else {

        return do given $fields {
            when Whatever { @res }
            when &valid-props($_) {
                @res.map({ $_.grep({ $_.key ∈ $fields }).Hash }).Array
            }
            default { die $errMsg; }
        }
    }
}


multi sub city-data(:$country = Whatever, :$state = Whatever, :$city = Whatever, :$fields is copy = Whatever, Bool :$nested = False) {
    return city-data([$country, $state, $city], :$fields, :$nested);
}

#============================================================
#| Makes Geographical identifier from given country, state, and city names.
proto sub make-geographics-id(|) is export {*}

multi sub make-geographics-id($country, $state, $city,
                              :$default-country = Whatever,
                              Str :$sep = '.',
                              Str :$spc = '_',
                              Str :$comma = '') {
    return make-geographics-id(:$country, :$state, :$city, :$default-country, :$sep, :$spc, :$comma);
}

multi sub make-geographics-id(:$country!, :$state!, :$city!,
                              :$default-country is copy = Whatever,
                              Str :$sep = '.',
                              Str :$spc = '_',
                              Str :$comma = '') {

    if $default-country.isa(Whatever) { $default-country = 'United_States'; }

    return do given ($country, $state, $city) {
        when (Whatever, Whatever, Whatever) {
            die 'At least one of the arguments have to be string.';
        }
        when (Whatever, Whatever, Str:D) {
            'CITYNAME' ~ $sep ~ $city.subst(/\h+/, $spc, :g);
        }
        when (Whatever, Str:D, Whatever) {
            'STATENAME' ~ $sep ~ $state.subst(/\h+/, $spc, :g);
        }
        when (Str:D, Whatever, Whatever) {
            'COUNTRYNAME' ~ $sep ~ $country.subst(/\h+/, $spc, :g);
        }
        when (Whatever, Str:D, Str:D) {
            # Of course, we have to verify that that ID can be found in the data.
            # But that is not done in this "lightweight" function.
            make-geographics-id($default-country, $state, $city, :$sep, :$spc);
        }
        default {
            ($country, $state, $city).join($sep).subst(/\h+/, $spc, :g).subst(',', $comma, :g);
        }
    }
}

#============================================================
sub interpret-geographics-id(Str $id, Bool :p(:$pairs) = False, Str :$sep = '.', Str :$spc = '_', Str :$comma = '') is export {
    my @parts = $id.split($sep);
    if $spc {
        @parts = @parts.map({ $_.subst($spc, ' '):g })
    }
    if $comma {
        @parts = @parts.map({ $_.subst($comma, ','):g })
    }
    if $pairs {
        if @parts.elems == 2 {
            return (<Type Name>.Array Z=> @parts).List;
        } elsif @parts.elems == 3 {
            return (<Country State City>.Array Z=> @parts).List;
        } else {
            warn 'Cannot interpret the geographics ID parititioning into pairs.';
            return Nil;
        }
    }
    return @parts;
}

#============================================================
# Geo-distance
#============================================================
#| Computes Geo-distance using the Haversine formula
proto sub geo-distance(|) is export {*}

multi sub geo-distance-meters($lat1, $lon1, $lat2, $lon2) {
    my $R = 6378.14*10**3;
    my $φ1 = $lat1 * π/180;
    my $φ2 = $lat2 * π/180;
    my $Δφ = ($lat2-$lat1) * π/180;
    my $Δλ = ($lon2-$lon1) * π/180;

    my $a = sin($Δφ/2) * sin($Δφ/2) + cos($φ1) * cos($φ2) * sin($Δλ/2) * sin($Δλ/2);
    my $c = 2 * atan2(sqrt($a), sqrt(1-$a));

    return $R * $c;
}

multi sub geo-distance($lat1, $lon1, $lat2, $lon2, $units = 'meters') {
    return do given $units {
        when Whatever { geo-distance-meters($lat1, $lon1, $lat2, $lon2); }
        when $_ ∈ <meters m> { geo-distance-meters($lat1, $lon1, $lat2, $lon2); }
        when $_ ∈ <kilometers km> { geo-distance-meters($lat1, $lon1, $lat2, $lon2) / 1000; }
        when $_ ∈ <yards yd> { geo-distance-meters($lat1, $lon1, $lat2, $lon2) * 1.094; }
        when $_ ∈ <miles mi> { geo-distance-meters($lat1, $lon1, $lat2, $lon2) / 1609.344; }
        default {
            die "The value of the last argument (or :\$units) is exptected to be one of 'meters', 'kilometers', 'yards', 'miles', or Whatever.";
        }
    }
}

multi sub geo-distance(($lat1, $lon1), ($lat2, $lon2), $units = 'meters') {
    return geo-distance($lat1, $lon1, $lat2, $lon2, $units);
}

multi sub geo-distance(($lat1, $lon1, $lat2, $lon2), $units = 'meters') {
    return geo-distance($lat1, $lon1, $lat2, $lon2, $units);
}

multi sub geo-distance($lat1, $lon1, $lat2, $lon2, :$units = 'meters') {
    return geo-distance($lat1, $lon1, $lat2, $lon2, $units);
}

multi sub geo-distance(($lat1, $lon1), ($lat2, $lon2), :$units = 'meters') {
    return geo-distance($lat1, $lon1, $lat2, $lon2, $units);
}

multi sub geo-distance(($lat1, $lon1, $lat2, $lon2), :$units = 'meters') {
    return geo-distance($lat1, $lon1, $lat2, $lon2, $units);
}

multi sub geo-distance(:$lat1, :$lon1, :$lat2, :$lon2, :$units = 'meters') {
    return geo-distance($lat1, $lon1, $lat2, $lon2, $units);
}

#============================================================
# GeoHash
#============================================================

#| Encode or decode geohashes
proto sub geohash(|) is export {*}

multi sub geohash(Str:D $spec where *.lc eq 'alphabet') {
    return Data::Geographics::GeoHash::geohash-alphabet();
}

multi sub geohash(Str:D $gh, Str:D :f(:$format) where *.lc eq 'neighbors') {
    return Data::Geographics::GeoHash::geohash-neighbors($gh);
}

multi sub geohash(Str:D $gh, :f(:$format) = Whatever) {
    my %res = Data::Geographics::GeoHash::geohash-decode($gh);
    return do given $format {
        when $_.isa(Whatever) || $_ ~~ Str:D && $_.lc eq 'mean' {
            %res.map({ $_.key => $_.value.values.sum / 2 }).Hash;
        }

        when $_ ~~ Str:D && $_.lc ∈ <point geoposition geo-position> {
            %res = %res.map({ $_.key => $_.values.values.sum / 2 });
            (%res<latitude>, %res<longitude>)
        }

        when $_ ~~ Str:D && $_.lc ∈ <box geoboundingbox geo-bounding-box bounding-box> {
            ((%res<latitude><min>, %res<longitude><min>),
             (%res<latitude><max>, %res<longitude><max>))
        }

        default {
            # "full" or Associative
            %res
        }
    }
}

multi sub geohash((Numeric:D $latitude, Numeric:D $longitude), *%args) {
    return geohash(:$latitude, :$longitude, |%args);
}
multi sub geohash(Numeric:D $latitude, Numeric:D $longitude, UInt :p(:$precision) = 9) {
    return Data::Geographics::GeoHash::geohash-encode(:$latitude, :$longitude, :$precision);
}

multi sub geohash(Numeric:D :lat(:$latitude), Numeric:D :lon(:$longitude), UInt :p(:$precision) = 9) {
    return Data::Geographics::GeoHash::geohash-encode(:$latitude, :$longitude, :$precision);
}

multi sub geohash(%h, UInt :p(:$precision) is copy = 9) {
    my $latitude = %h<latitude> // %h<lat>;
    my $longitude = %h<longitude> // %h<lon>;
    $precision = %h<precision> // %h<prec> // $precision;

    die "Cannot find latitude and longitude in given Associative object."
    unless $latitude.definded && $longitude.define;

    return Data::Geographics::GeoHash::geohash-encode(:$latitude, :$longitude, :$precision);
}


#============================================================
# Optimization
#============================================================
BEGIN {
    ingest-city-data(sep => Whatever);
    ingest-country-data();
}
