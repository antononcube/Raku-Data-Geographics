# Data::Geographics

Raku package for geographical data (like, country data, city data, etc.)

Provides the functions `country-data` and `city-data`. 

-----

## Installation

From [Zef ecosystem](https://raku.land):

```
zef install Data::Geographics
```

From GitHub:

```
zef install https://github.com/antononcube/Raku-Data-Geographics.git
```

----

## Using city-data Function

The `city-data` function is a powerful tool for retrieving and analyzing geographic data. Below is an example of how to use it.

First, we need to import the necessary modules:

```raku
use Data::Geographics;
use Data::TypeSystem;
use Data::Reshapers;
use Data::Summarizers;
```

Then, we can call the `city-data` function to get an array of city data:

```raku
my @dsCityData = city-data();
@dsCityData.&dimensions 
```

We can then use the `records-summary` function to get a summary of the city data:

```raku
records-summary(@dsCityData);
```

We can group the city data by country and print the number of cities in each country in a pretty table:

```raku
group-by(@dsCityData, <Country>).Array.map({ $_.key => $_.value.elems }).Hash
        ==> to-pretty-table()
        ==> say();
```

We can also get a nested hash of city data grouped by country, state, and city:

```raku
my %countryStateCity = city-data():nested;
%countryStateCity.elems
```

We can then use the `deduce-type` function (from "Data::TypeSystem") to get the type of the nested hash:

```raku
say deduce-type(%countryStateCity<Bulgaria>);
```

We can get the first defined record for the city of Stara Zagora in Bulgaria:

```raku
say %countryStateCity{'Bulgaria';*;'Stara Zagora'}.grep(*.defined).head;
```

We can also get the latitude and longitude of Stara Zagora:

```raku
say %countryStateCity{'Bulgaria';*;'Stara Zagora';'Latitude'}.grep(*.defined).head;
say %countryStateCity{'Bulgaria';*;'Stara Zagora';'Longitude'}.grep(*.defined).head;
```

-----

## NER and data retrieval

In this section we show how to use Named Entity Recognition (NER) of Geo-locations provided by "DSL::Entity::Geographics", [AAp1],
together with the Geo-data provided by this package, ("Data::Geographics").


In this code, `$geoID` is obtained by calling the `ToGeographicEntityCode` function with a string `$s` and the *target* "Raku-System".

```raku
use DSL::Entity::Geographics;

my $s = 'Fort Lauderdale, FL';
my $geoID = ToGeographicEntityCode($s, 'Raku-System');
```

The `interpret-geographics-id` function is then used to interpret `$geoID` into its constituent parts, which are stored in `%geoIDParts`.

```raku
my %geoIDParts = interpret-geographics-id($geoID):p;
```

Depending on whether the `Type` of `%geoIDParts` is "CITYNAME" or not, 
the code then fetches the corresponding geographic data from `%countryStateCity` and stores it in `$res`.

```raku
my $res = do if %geoIDParts<Type> // 'NONE' eq 'CITYNAME' {
    %countryStateCity{'United States';*;%geoIDParts<Name>}.grep(*.defined);
} else {
    %countryStateCity{'United States';%geoIDParts<State>;%geoIDParts<City>};
}

say $res;
```


----

## References

[AAp1] Anton Antonov,
[DSL::Entity::Geographics Raku package](),
(2023-2024),
[GitHub/antononcube](https://github.com/antononcube/Raku-DSL-Entity-Geographics).
