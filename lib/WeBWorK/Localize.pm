package WeBWorK::Localize;

use File::Spec;

use Locale::Maketext;
use Locale::Maketext::Lexicon;

my $path     = "$ENV{RENDER_ROOT}/lib/WeBWorK/Localize";
my $pattern  = File::Spec->catfile($path, '*.[pm]o');
my $decode   = 1;
my $encoding = undef;

eval "
	package WeBWorK::Localize::I18N;
	use base 'Locale::Maketext';
    %WeBWorK::Localize::I18N::Lexicon = ( '_AUTO' => 1 );
	Locale::Maketext::Lexicon->import({
	    'i-default' => [ 'Auto' ],
	    '*'	=> [ Gettext => \$pattern ],
	    _decode => \$decode,
	    _encoding => \$encoding,
	});
	*tense = sub { \$_[1] . ((\$_[2] eq 'present') ? 'ing' : 'ed') };

" or die "Can't process eval in WeBWorK/Localize.pm: line 35:  ". $@;

package WeBWorK::Localize;

# This subroutine is shared with the safe compartment in PG to
# allow maketext() to be constructed in PG problems and macros
# It seems to be a little fragile -- possibly it breaks
# on perl 5.8.8
sub getLoc {
	my $lang = shift;
	my $lh = WeBWorK::Localize::I18N->get_handle($lang);
	return sub {$lh->maketext(@_)};
}

sub getLangHandle {
	my $lang = shift;
	my $lh = WeBWorK::Localize::I18N->get_handle($lang);
	return $lh;
}

# this is like [quant] but it doesn't write the number
#  usage: [quant,_1,<singular>,<plural>,<optional zero>]

sub plural {
    my($handle, $num, @forms) = @_;

    return "" if @forms == 0;
    return $forms[2] if @forms > 2 and $num == 0;

    # Normal case:
    return(  $handle->numerate($num, @forms) );
}

# this is like [quant] but it also has -1 case
#  usage: [negquant,_1,<neg case>,<singular>,<plural>,<optional zero>]

sub negquant {
    my($handle, $num, @forms) = @_;

    return $num if @forms == 0;

    my $negcase = shift @forms;
    return $negcase if $num < 0;

    return $forms[2] if @forms > 2 and $num == 0;
    return( $handle->numf($num) . ' ' . $handle->numerate($num, @forms) );
}

%Lexicon = (
	    '_AUTO' => 1,
	   );

package WeBWorK::Localize::I18N;
use base(WeBWorK::Localize);

1;
