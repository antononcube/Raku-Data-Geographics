#!/usr/bin/env raku
use v6.d;

use Data::Geographics;
use Data::Reshapers;
use Data::Summarizers;

#`[
my $tstart0 = now;
ingest-city-data();
my $tend0 = now;

say "Ingestion time {$tend - $tstart}.";
]

my @dsCities = city-data();
say(@dsCities.elems);

.say for @dsCities.head(12);


#records-summary(@dsCities);

say '=' x 120;

my $tstart = now;

#my @res = @dsCities.grep({ $_<City> ~~ / Atlanta /});
my @res = city-data( 'Atlanta' );

my $tend = now;
say "Search time {$tend - $tstart}.";
.say for @res;


say '=' x 120;

$tstart = now;
@res = city-data(city => / ^ Atlanta $ /);
$tend = now;

say "Search time {$tend - $tstart}.";

.say for @res;

say @res.elems;
