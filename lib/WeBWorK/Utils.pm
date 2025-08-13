package WeBWorK::Utils;
use base qw(Exporter);

use strict;
use warnings;

our @EXPORT_OK = qw(wwRound);

# usage wwRound($places,$float)
# return $float rounded up to number of decimal places given by $places
sub wwRound(@) {
	my $places = shift;
	my $float  = shift;
	my $factor = 10**$places;
	return int($float * $factor + 0.5) / $factor;
}

1;
