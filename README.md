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
```
# (Any)
```

Then, we can call the `city-data` function to get an array of city data:

```raku
my @dsCityData = city-data();
@dsCityData.&dimensions 
```
```
# (62350 8)
```

We can then use the `records-summary` function to get a summary of the city data:

```raku
records-summary(@dsCityData);
```
```
# +-------------------------------+------------------------+-----------------------+------------------+----------------------+-------------------------------+---------------------------------------------+------------------------------------+
# | Longitude                     | Country                | Population            | Elevation        | City                 | State                         | ID                                          | Latitude                           |
# +-------------------------------+------------------------+-----------------------+------------------+----------------------+-------------------------------+---------------------------------------------+------------------------------------+
# | Min    => -179.5              | United States => 32796 | Min    => 0           | null    => 7380  | Franklin    => 41    | Rhineland‐Palatinate => 2266  | United_States.Wisconsin.Lincoln    => 12    | Min    => -26.900000000000002      |
# | 1st-Qu => -90.266519          | Germany       => 12539 | 1st-Qu => 418         | 1100    => 395   | null        => 34    | Bavaria              => 2045  | United_States.Wisconsin.Washington => 8     | 1st-Qu => 39.0522021               |
# | Mean   => -42.020578865598914 | Spain         => 7896  | Mean   => 9484.230714 | 0       => 346   | Lincoln     => 33    | New York             => 1854  | United_States.Wisconsin.Scott      => 7     | Mean   => 42.936357056980571624619 |
# | Median => -73.6671523         | Russia        => 4644  | Median => 1486        | 110     => 331   | Washington  => 33    | Pennsylvania         => 1805  | United_States.Wisconsin.Union      => 7     | Median => 42.4648803               |
# | 3rd-Qu => 9.620000000000001   | Ukraine       => 1832  | 3rd-Qu => 5106        | 3       => 320   | Clinton     => 30    | Wisconsin            => 1785  | United_States.Wisconsin.Harrison   => 6     | 3rd-Qu => 49.02                    |
# | Max    => 179.32              | Canada        => 1008  | Max    => 13010112    | 1.3     => 315   | Springfield => 30    | Texas                => 1756  | United_States.Wisconsin.Grant      => 6     | Max    => 82.501389                |
# |                               | Hungary       => 850   |                       | 120     => 293   | Georgetown  => 29    | California           => 1539  | United_States.Wisconsin.Wilson     => 6     |                                    |
# |                               | (Other)       => 785   |                       | (Other) => 52970 | (Other)     => 62120 | (Other)              => 49300 | (Other)                            => 62298 |                                    |
# +-------------------------------+------------------------+-----------------------+------------------+----------------------+-------------------------------+---------------------------------------------+------------------------------------+
```

We can group the city data by country and print the number of cities in each country in a pretty table:

```raku
group-by(@dsCityData, <Country>).Array.map({ $_.key => $_.value.elems }).Hash
        ==> to-pretty-table()
        ==> say();
```
```
# +-------+---------------+
# | Value |      Key      |
# +-------+---------------+
# |  1008 |     Canada    |
# | 32796 | United States |
# |  261  |    Bulgaria   |
# |  4644 |     Russia    |
# |  850  |    Hungary    |
# | 12539 |    Germany    |
# |  524  |    Botswana   |
# |  1832 |    Ukraine    |
# |  7896 |     Spain     |
# +-------+---------------+
```

We can also get a nested hash of city data grouped by country, state, and city:

```raku
my %countryStateCity = city-data():nested;
%countryStateCity.elems
```
```
# 9
```

We can then use the `deduce-type` function (from "Data::TypeSystem") to get the type of the nested hash:

```raku
say deduce-type(%countryStateCity<Bulgaria>);
```
```
# Assoc(Atom((Str)), (Any), 28)
```

We can get the first defined record for the city of Stara Zagora in Bulgaria:

```raku
say %countryStateCity{'Bulgaria';*;'Stara Zagora'}.grep(*.defined).head;
```
```
# {City => Stara Zagora, Country => Bulgaria, Elevation => 2.2, Latitude => 42.42, Longitude => 25.63, Population => 140710, State => Stara Zagora}
```

We can also get the latitude and longitude of Stara Zagora:

```raku
say %countryStateCity{'Bulgaria';*;'Stara Zagora';'Latitude'}.grep(*.defined).head;
say %countryStateCity{'Bulgaria';*;'Stara Zagora';'Longitude'}.grep(*.defined).head;
```
```
# 42.42
# 25.63
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
```
# United_States.Florida.Fort_Lauderdale
```

The `interpret-geographics-id` function is then used to interpret `$geoID` into its constituent parts, which are stored in `%geoIDParts`.

```raku
my %geoIDParts = interpret-geographics-id($geoID):p;
```
```
# {City => Fort Lauderdale, Country => United States, State => Florida}
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
```
# ({City => Fort Lauderdale, Country => United States, Elevation => 1, Latitude => 26.141305, Longitude => -80.143896, Population => 182760, State => Florida})
```


----

## References

[AAp1] Anton Antonov,
[DSL::Entity::Geographics Raku package](),
(2023-2024),
[GitHub/antononcube](https://github.com/antononcube/Raku-DSL-Entity-Geographics).
