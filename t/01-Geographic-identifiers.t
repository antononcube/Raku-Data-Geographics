
use Data::Geographics;
use Test;

##===========================================================
## Country names
##===========================================================

my $sep = '-';
my $spc = '_';
my $comma = '';

plan 7;

# 1
is make-geographics-id( country => 'United States', state => 'Georgia', city => 'Atlanta', :$sep, :$spc, :$comma), 'United_States-Georgia-Atlanta';

# 2
is make-geographics-id('United States', 'Georgia', 'Atlanta', :$sep, :$spc, :$comma), 'United_States-Georgia-Atlanta';

# 3
is make-geographics-id(Whatever, Whatever, 'Fort Lauderdale', :$sep, :$spc, :$comma), 'CITYNAME-Fort_Lauderdale';

# 4
is make-geographics-id(Whatever, 'Georgia', Whatever, :$sep, :$spc, :$comma), 'STATENAME-Georgia';

# 5
is make-geographics-id(Whatever, 'Florida', 'Fort Lauderdale', :$sep, :$spc, :$comma), 'United_States-Florida-Fort_Lauderdale';

# 6
is make-geographics-id('Russia', Whatever, Whatever, :$sep, :$spc, :$comma), 'COUNTRYNAME-Russia';

# 7
is make-geographics-id('Bulgaria', 'Plovdiv', 'Sopot, Plovdiv Province', :$sep, :$spc, :$comma), 'Bulgaria-Plovdiv-Sopot_Plovdiv_Province';

done-testing;
