#!/usr/bin/env raku
use v6.d;

use Data::Geographics;
use Data::TypeSystem;
use Data::Reshapers;
use Data::Summarizers;

my @dsCityData = city-data();

records-summary(@dsCityData);

group-by(@dsCityData, <Country>).Array.map({ $_.key => $_.value.elems }).Hash
        ==> to-pretty-table()
        ==> say();

my %countryStateCity3 = @dsCityData
        .classify(*<Country>)
        .map({ $_.key => $_.value.classify(*<State>)
                .map({ $_.key => $_.value.map({ $_<City> => $_.grep({ $_.key ∈ <Population Latitude Longitude ID> }).Hash }).Hash }).Hash });

say deduce-type(%countryStateCity3);

say %countryStateCity3{'Bulgaria';*;'Stara Zagora'}.grep(*.defined).head;

say %countryStateCity3{'Bulgaria';*;'Stara Zagora';'Latitude'}.grep(*.defined).head;
say %countryStateCity3{'Bulgaria';*;'Stara Zagora';'Longitude'}.grep(*.defined).head;