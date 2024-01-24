#!/usr/bin/env raku
use v6.d;

use Data::Geographics;
use Data::Reshapers;
use Data::Summarizers;
use Data::TypeSystem;
use Text::Plot;

my $tstart = now;
ingest-country-data();
my $tend = now;

say "Ingestion time {$tend - $tstart}.";

my @dsCountries = country-data();

.say for @dsCountries.head(4).map({ $_.key => $_.value.pick(4) });

#========================================================================================================================
say '=' x 120;

$tstart = now;
my %res = country-data(/ Bulg /);
$tend = now;

say "Search time {$tend - $tstart}.";

.say for %res.pairs.pick(4);

#========================================================================================================================
say '=' x 120;

say do given country-data('Properties').join(' ').match(:e, / <.wb> (G .*) /) { $/>>.Str };

$tstart = now;
%res = country-data(Whatever, 'GDP');
$tend = now;

say %res;
say deduce-type(%res);

say "Search time {$tend - $tstart}.";

say text-pareto-principle-plot(%res.values.List);