unit module Data::Geographics;

use JSON::Fast;

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
proto sub city-data(|) is export {*}

multi sub city-data($spec, $fields = Whatever) {
    return city-data($spec, :$fields);
}

multi sub city-data($spec, :$fields is copy = Whatever) {

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

    # Return result with required properties
    return do given $fields {
        when Whatever { @res }
        when ($_ ~~ Positional) && ($_.all ~~ Str:D) && ($_ (-) @city-record-fields).elems == 0 {
            @res.map({ $_.grep({ $_.key ∈ $fields }).Hash }).Array
        }
        default {
            die "The second argument is expected to a string, a list of strings, or Whatever."
        }
    }
}


multi sub city-data(:$country = Whatever, :$state = Whatever, :$city = Whatever, :$fields is copy = Whatever) {
    return city-data([$country, $state, $city], :$fields);
}

#============================================================
#| Makes Geographical identifier from given country, state, and city names.
proto sub make-geographics-id(|) is export {*}

multi sub make-geographics-id($country, $state, $city,
                              :$default-country = Whatever,
                              Str :$sep = '|',
                              Str :$spc = '_',
                              Str :$comma = '') {
    return make-geographics-id(:$country, :$state, :$city, :$default-country, :$sep, :$spc, :$comma);
}

multi sub make-geographics-id(:$country!, :$state!, :$city!,
                              :$default-country is copy = Whatever,
                              Str :$sep = '|',
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
# Optimization
#============================================================
BEGIN {
    ingest-city-data(sep => Whatever);
    ingest-country-data();
}
