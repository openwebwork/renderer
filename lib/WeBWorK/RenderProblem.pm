package WeBWorK::RenderProblem;

use strict;
use warnings;

# for logs
use Time::HiRes qw/time/;
use Proc::ProcessTable;

use Mojo::File;
use Mojo::JSON  qw( encode_json );
use Crypt::JWT  qw( encode_jwt );
use Digest::MD5 qw( md5_hex );

use lib Mojo::File::curfile->dirname->dirname->child('PG', 'lib');

use WeBWorK::PG;
use WeBWorK::Utils::Tags;

my $renderRoot = Mojo::File::curfile->dirname->dirname->dirname;

##################################################
# define universal TO_JSON for JSON::XS unbless
##################################################

sub UNIVERSAL::TO_JSON {
	my ($self) = shift;

	use Storable              qw(dclone);
	use Data::Structure::Util qw(unbless);

	my $clone = unbless(dclone($self));

	$clone;
}

##########################################################
#  END MAIN :: BEGIN SUBROUTINES
##########################################################

#######################################################################
# Process the pg file
#######################################################################

sub process_pg_file {
	my ($problem, $inputs_ref) = @_;

	# just make sure we have the fundamentals covered...
	$inputs_ref->{displayMode}  ||= 'MathJax';
	$inputs_ref->{outputFormat} ||= $inputs_ref->{outputformat} || 'default';
	$inputs_ref->{language}     ||= 'en';
	$inputs_ref->{isInstructor} //= ($inputs_ref->{permissionLevel} // 0) >= 10;
	# HACK: required for problemRandomize.pl
	$inputs_ref->{effectiveUser} = 'red.ted';
	$inputs_ref->{user}          = 'red.ted';

	my $pg_start         = time;
	my $memory_use_start = get_current_process_memory();

	my ($return_object, $error_flag, $error_string) = process_problem($problem, $inputs_ref);

	my $pg_stop        = time;
	my $pg_duration    = $pg_stop - $pg_start;
	my $log_file_path  = $inputs_ref->{sourceFilePath} || 'source provided without path';
	my $memory_use_end = get_current_process_memory();
	my $memory_use     = $memory_use_end - $memory_use_start;
	$problem->c->resourceUsageLog(
		sprintf("(duration: %.3f sec) ", $pg_duration)
			. sprintf("{memory: %6d bytes} ", $memory_use)
			. "file: $log_file_path"
			. $error_flag ? $error_string : '');

	# havoc caused by problemRandomize.pl inserting CODE ref into pg->{flags}
	# HACK: remove flags->{problemRandomize} if it exists -- cannot include CODE refs
	delete $return_object->{flags}{problemRandomize}
		if $return_object->{flags}{problemRandomize};
	# similar things happen with compoundProblem -- delete CODE refs
	delete $return_object->{flags}{compoundProblem}{grader}
		if $return_object->{flags}{compoundProblem}{grader};

	$return_object->{tags} = WeBWorK::Utils::Tags->new($inputs_ref->{sourceFilePath}, $problem->source)
		if ($inputs_ref->{includeTags});

	my $json = encode_json($return_object);
	return $json;
}

#######################################################################
# Process Problem
#######################################################################

sub process_problem {
	my ($problem, $inputs_ref) = @_;

	my $source    = $problem->{problem_contents};
	my $file_path = $inputs_ref->{sourceFilePath} || $inputs_ref->{problemSourceURL};
	my ($raw_metadata_text, $problemUUID);

	# TODO: include problemUUID from problemSourceURL and skip this if present
	if ($source =~ m|^(.*?)(&?DOCUMENT\s*\(?.*?\)?\s*;.*?&?ENDDOCUMENT\s*\(?\s*\)?\s*;?)(.*)$|s) {
		$raw_metadata_text = $1;
		my $body = $2;
		$body =~ s|#.*$||g;    # strip commments before hashing
		$body =~ s|\s||gm;     # strip whitespace before hashing
		$problemUUID = md5_hex(Encode::encode_utf8($body));
	} else {
		$raw_metadata_text = 'no-document';
		$problemUUID       = 'no-document';
	}
	warn "Mismatched problemUUID (incoming: $inputs_ref->{problemUUID}) (computed: $problemUUID)"
		if (defined $inputs_ref->{problemUUID} && $inputs_ref->{problemUUID} ne $problemUUID);
	$inputs_ref->{problemUUID} //= $problemUUID;

	# external dependencies on pg content is not recorded by PGalias
	# record the dependency separately -- TODO: incorporate into PG.pl or PGcore?
	my @pgResources;
	while ($source =~ m/includePG(?:problem|file)\(\s*["'](.*)["']\s*\);/g) {
		push @pgResources, $1;
	}

	##################################################
	# Process the pg file
	##################################################
	our ($return_object, $error_flag, $error_string);
	$error_flag   = 0;
	$error_string = '';

	# can include @args as third input below
	$return_object = renderPG($problem->c, \$source, $inputs_ref);

	# stash assets list in $return_object
	$return_object->{pgResources}       = \@pgResources;
	$return_object->{raw_metadata_text} = $raw_metadata_text if $inputs_ref->{includeTags};

	# generate sessionJWT to store session data and answerJWT to update grade store
	if ($inputs_ref->{previewAnswers}) {
		# if this is a preview, leave session unmodified, and no answerJWT
		$return_object->{sessionJWT} = $inputs_ref->{sessionJWT};
	} elsif ($inputs_ref->{problemJWT}) {
		my ($sessionJWT, $answerJWT) = generateJWTs($problem->c, $return_object, $inputs_ref);
		$return_object->{sessionJWT} = $sessionJWT;
		$return_object->{answerJWT}  = $answerJWT;
	}

	#######################################################################
	# Handle errors
	#######################################################################

	if (not defined $return_object) {
		$error_string = " could not be processed";
	} elsif (defined $return_object->{flags}{error_flag}
		&& $return_object->{flags}{error_flag})
	{
		$error_string = " has errors";
	} elsif (defined($return_object->{errors}) && $return_object->{errors}) {
		$error_string = " has syntax errors";
	}
	$error_flag = 1 if $return_object->{errors};

	#######################################################################
	# End processing of the pg file
	#######################################################################

	return $return_object, $error_flag, $error_string;
}

###########################################
# standalonePGproblemRenderer
###########################################

sub renderPG {
	my $c           = shift;
	my $problemFile = shift // '';
	my $inputs_ref  = shift // {};
	my %args        = @_;

	my $processAnswers = $inputs_ref->{processAnswers} // 1;

	my $isPreview = defined($inputs_ref->{previewAnswers}) ? 1 : 0;
	my $isSubmit  = defined($inputs_ref->{submitAnswers})  ? 1 : 0;
	my $showSolutions =
		($inputs_ref->{isInstructor} ? 1 : 0) || $inputs_ref->{showCorrectAnswers} || $inputs_ref->{showSolutions};
	my $showHints      = $showSolutions || $inputs_ref->{showHints};
	my $displayResults = $inputs_ref->{answersSubmitted} && !$isPreview;
	my $forceResults   = $displayResults                 && $inputs_ref->{showPartialCorrectAnswers};

	my $pg = WeBWorK::PG->new(
		inputs_ref              => {%$inputs_ref},                        # preserve original values
		sourceFilePath          => $inputs_ref->{sourceFilePath} // '',
		r_source                => $problemFile,
		problemSeed             => $inputs_ref->{problemSeed},
		processAnswers          => $processAnswers,
		showFeedback            => 1,
		showAttemptResults      => $displayResults,                       # respects showPartialCorrectAnswers
		forceShowAttemptResults => $forceResults,                         # overrides showPartialCorrectAnswers
		showAttemptAnswers      => $isPreview,                            # display string version of submitted answer
		showAttemptPreviews     => 1,                                     # display LaTeX version of submitted answer
		showHints               => $showHints,                            # default is to showHint (set in PG.pm)
		showSolutions           => $showSolutions,
		showCorrectAnswers      => $inputs_ref->{showCorrectAnswers} ? 2 : 0,
		num_of_correct_ans      => $inputs_ref->{numCorrect}   || 0,
		num_of_incorrect_ans    => $inputs_ref->{numIncorrect} || 0,
		displayMode             => $inputs_ref->{displayMode},
		useMathQuill            => !defined $inputs_ref->{entryAssist} || $inputs_ref->{entryAssist} eq 'MathQuill',
		answerPrefix            => $inputs_ref->{answerPrefix},
		isInstructor            => $inputs_ref->{isInstructor},
		forceScaffoldsOpen      => $inputs_ref->{forceScaffoldsOpen},
		psvn                    => $inputs_ref->{psvn},
		problemUUID             => $inputs_ref->{problemUUID},
		language                => $inputs_ref->{language} // 'en',
		templateDirectory       => "$renderRoot/",
		htmlURL                 => $c->url_for('pgFile',     static => '')->to_string,
		tempURL                 => $c->url_for('pgTempFile', static => '')->to_string,
		debuggingOptions        => {
			show_resource_info          => $inputs_ref->{show_resource_info},
			view_problem_debugging_info => $inputs_ref->{view_problem_debugging_info}
				// $inputs_ref->{isInstructor},
			show_pg_info           => $inputs_ref->{show_pg_info},
			show_answer_hash_info  => $inputs_ref->{show_answer_hash_info},
			show_answer_group_info => $inputs_ref->{show_answer_group_info}
		}
	);

	# new version of output:
	my $ret = {
		text             => $pg->{body_text},
		header_text      => $pg->{head_text},
		post_header_text => $pg->{post_header_text},
		answers          => $pg->{answers},            # unbless?
		errors           => $pg->{errors},
		pg_warnings      => $pg->{warnings},
		problem_result   => $pg->{result},
		problem_state    => $pg->{state},
		flags            => $pg->{flags},
	};
	if (ref($pg->{pgcore}) eq 'PGcore') {
		$ret->{internal_debug_messages} = $pg->{pgcore}->get_internal_debug_messages();
		$ret->{warning_messages}        = $pg->{pgcore}->get_warning_messages();
		$ret->{debug_messages}          = $pg->{pgcore}->get_debug_messages();
		# $ret->{resources}                = [ keys %{ $pg->{pgcore}{PG_alias}{resource_list} } ];
		$ret->{PERSISTENCE_HASH_UPDATED} = $pg->{pgcore}{PERSISTENCE_HASH_UPDATED};
		$ret->{PERSISTENCE_HASH}         = $pg->{pgcore}{PERSISTENCE_HASH};
		$ret->{PG_ANSWERS_HASH}          = {
			map {
				$_ => {
					response_obj => unbless($pg->{pgcore}{PG_ANSWERS_HASH}{$_}->response_obj),
					rh_ans       => $pg->{pgcore}{PG_ANSWERS_HASH}{$_}{ans_eval}{rh_ans}
				}
			}
				keys %{ $pg->{pgcore}{PG_ANSWERS_HASH} }
		};
		# TODO: replace resources after PG merges #1046
		$ret->{resources} = {
			map { $_ => $pg->{pgcore}{PG_alias}{resource_list}{$_}{uri} }
				keys %{ $pg->{pgcore}{PG_alias}{resource_list} }
		};
	} else {
		$ret->{internal_debug_messages} = ['Problem failed during render - no PGcore received.'];
	}
	$pg->free;
	return $ret;
}

##################################################
# utilities
##################################################

sub get_current_process_memory {
	CORE::state $pt = Proc::ProcessTable->new;
	my %info = map { $_->pid => $_ } @{ $pt->table };
	return $info{$$}->rss;
}

# expects a pg/result_object and a ref to submitted formdata
# generates a sessionJWT and an answerJWT
sub generateJWTs {
	my $c          = shift;
	my $pg         = shift;
	my $inputs_ref = shift;

	my $sessionHash = {
		iss              => $c->config->{SITE_HOST},
		answersSubmitted => 1,
		sessionID        => $inputs_ref->{sessionID},
		problemUUID      => $inputs_ref->{problemUUID},
		problemJWT       => $inputs_ref->{problemJWT},
	};
	my $scoreHash = {
		result  => $pg->{problem_result}{score},
		answers => unbless($pg->{answers}),
	};

	# once the correct answers are shown, this setting is permanent
	if ($inputs_ref->{showCorrectAnswers} && !$inputs_ref->{isInstructor}) {
		$sessionHash->{showCorrectAnswers} = 1;
		$sessionHash->{isLocked}           = 1;
	}

	# store the current answer/response state for each entry
	for my $ans (@{ $pg->{flags}{KEPT_EXTRA_ANSWERS} }) {
		$sessionHash->{$ans} = $inputs_ref->{$ans};
	}

	# update the number of correct/incorrect submissions if answers were 'submitted'
	# but don't update either if the problem was already correct
	$sessionHash->{numCorrect} =
		(defined $inputs_ref->{submitAnswers} && $inputs_ref->{numCorrect} == 0)
		? $pg->{problem_state}{num_of_correct_ans}
		: ($inputs_ref->{numCorrect} // 0);
	$sessionHash->{numIncorrect} =
		(defined $inputs_ref->{submitAnswers} && $inputs_ref->{numCorrect} == 0)
		? $pg->{problem_state}{num_of_incorrect_ans}
		: ($inputs_ref->{numIncorrect} // 0);

	# create the session JWT
	my $sessionJWT =
		encode_jwt(payload => $sessionHash, auto_iat => 1, alg => 'HS256', key => $c->config->{webworkJWTsecret});

	# form answerJWT
	my $responseHash = {
		iss        => $c->config->{SITE_HOST},
		aud        => $inputs_ref->{JWTanswerURL},
		score      => $scoreHash,
		sessionJWT => $sessionJWT,
		platform   => 'renderer'
	};

	# Can instead use alg => 'PBES2-HS512+A256KW', enc => 'A256GCM' for JWE
	my $answerJWT =
		encode_jwt(payload => $responseHash, alg => 'HS256', key => $c->config->{problemJWTsecret}, auto_iat => 1);
	return ($sessionJWT, $answerJWT);
}

sub pretty_print_rh {
	shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $rh     = shift;
	my $indent = shift || 0;
	my $out    = "";
	my $type   = ref($rh);

	if (defined($type) and $type) {
		$out .= " type = $type; ";
	} elsif (!defined($rh)) {
		$out .= " type = UNDEFINED; ";
	}
	return $out . " " unless defined($rh);

	if (ref($rh) =~ /HASH/) {
		$out .= "{\n";
		$indent++;
		for my $key (sort keys %{$rh}) {
			$out .= "  " x $indent . "$key => " . pretty_print_rh($rh->{$key}, $indent) . "\n";
		}
		$indent--;
		$out .= "\n" . "  " x $indent . "}\n";

	} elsif (ref($rh) =~ /ARRAY/ or "$rh" =~ /ARRAY/) {
		$out .= " ( ";
		foreach my $elem (@{$rh}) {
			$out .= pretty_print_rh($elem, $indent);

		}
		$out .= " ) \n";
	} elsif (ref($rh) =~ /SCALAR/) {
		$out .= "scalar reference " . ${$rh};
	} elsif (ref($rh) =~ /Base64/) {
		$out .= "base64 reference " . $$rh;
	} else {
		$out .= $rh;
	}

	return $out . " ";
}

1;
