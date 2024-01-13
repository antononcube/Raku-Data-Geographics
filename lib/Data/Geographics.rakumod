unit module Data::Geographics;

use JSON::Fast;

#============================================================
my %country-records;
my @country-record-fields;

#| Ingest the country data database.
sub ingest-prompt-data() is export {
    # It is expected that resource file "prompts.json" is an array of hashes.
    %country-records = from-json(slurp(%?RESOURCES<aCountryData.json>)).List;

    @country-record-fields = %country-records.map({ $_.keys }).flat.unique.sort;

    return %(:%country-records, :@country-record-fields);
}

#============================================================
my @city-records;
my @city-record-fields;

#| Ingest the city data database.
sub ingest-city-data(Str :$sep = ',') is export {

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

    my @fileNames = $cityDataFileNames.lines>>.trim;

    @city-records = [];
    @city-record-fields = [];
    for @fileNames -> $fileName {
        # It 7-10 faster to use this ad-hoc code than the standard Text::CSV workflow.
        # But some tags might have commas (i.e. the separator) in them.
        my $fileHandle = %?RESOURCES{$fileName}.IO;
        my Str @records = $fileHandle.lines;
        my @colNames = @records[0].split($sep).map({ $_.subst(/ ^ '"' | '"' $/):g }).Array;
        my @res = @records[1 .. *- 1].map({ (@colNames Z=> $_.split($sep).map({ $_.subst(/ ^ '"' | '"' $/):g }) ).Hash }).Array;
        @city-record-fields = [|@city-record-fields, |@colNames].unique.Array;
        @city-records.append(@res);
    }

    if @city-record-fields.sort !eqv ["Country", "State", "City", "Population", "Latitude", "Longitude", "Elevation"].sort {
        note 'Unexpected column names.';
    }

    return %(:@city-records, :@city-record-fields);
}

#============================================================
proto sub country-data($spec, |) is export {*}

multi sub country-data($spec, $prop) {

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
        when $_ ~~ Str:D && $_.lc ∈ <propreties fields> {
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
    if $fields ~~ Str:D { $fields = [$fields, ]; }

    # Return result with required properties
    return do given $fields {
        when Whatever { @res }
        when $_ ~~ Positional && $_.all ~~ Str:D && ($_ (-) @city-record-fields).elems == 0 {
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
# Optimization
#============================================================
BEGIN {
    ingest-city-data(sep => ',')
}
