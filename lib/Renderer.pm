package Renderer;
use Mojo::Base 'Mojolicious';

use Mojo::File;
use Env qw(RENDER_ROOT PG_ROOT baseURL);
use Date::Format;

BEGIN {
	# RENDER_ROOT and PG_ROOT are required for the WeBWorK::PG::Environment.
	$RENDER_ROOT = Mojo::File::curfile->dirname->dirname;
	$PG_ROOT     = Mojo::File::curfile->dirname->child('PG');
}

use Renderer::Model::Problem;
use Renderer::Controller::IO;
use WeBWorK::FormatRenderedProblem;

sub startup {
	my $self = shift;

	$self->plugin('Config');
	$self->secrets($self->config('secrets'));

	$self->sanitizeHostURLs;

	# This is also required for the WeBWorK::PG::Environment, but is not needed at compile time.
	$baseURL = $self->config->{baseURL};

	say 'Renderer is based at ' . $self->defaults->{baseHREF};
	say 'Problem attempts will be sent to ' . $self->defaults->{formURL};

	$self->plugin('Renderer::Plugin::Assets');

	# Handle optional CORS settings
	if (my $CORS_ORIGIN = $self->config('CORS_ORIGIN')) {
		die "CORS_ORIGIN ($CORS_ORIGIN) must be an absolute URL or '*'"
			unless ($CORS_ORIGIN eq '*' || $CORS_ORIGIN =~ /^https?:\/\//);

		warn "*** [CONFIG] Using '*' for CORS_ORIGIN is insecure\n"
			if ($CORS_ORIGIN eq '*');

		$self->hook(
			before_dispatch => sub {
				my $c = shift;
				$c->res->headers->header('Access-Control-Allow-Origin' => $CORS_ORIGIN);
			}
		);
	}

	# Logging
	if ($ENV{MOJO_MODE} && $ENV{MOJO_MODE} eq 'production') {
		my $logPath = $self->home->child('logs', 'error.log');
		say "[LOGS] Running in production mode, logging to $logPath";
		$self->log(Mojo::Log->new(
			path  => $logPath,
			level => ($ENV{MOJO_LOG_LEVEL} || 'warn')
		));
	}

	if ($self->config('INTERACTION_LOG')) {
		my $interactionLogPath = $self->home->child('logs', 'interactions.log');
		say "[LOGS] Saving interactions to $interactionLogPath";
		my $resultsLog = Mojo::Log->new(path => $interactionLogPath, level => 'info');
		$resultsLog->format(sub {
			my ($time, $level, @lines) = @_;
			my $start = shift(@lines);
			return sprintf "%s, %s, %s\n", $start, $time - $start, join(', ', @lines);
		});
		$self->helper(logAttempt => sub { shift; $resultsLog->info(@_); });
	}

	my $resourceUsageLog = Mojo::Log->new(path => $self->home->child('logs', 'resource_usage.log'));
	$resourceUsageLog->format(sub {
		my ($time, $level, @lines) = @_;
		return '[' . time2str('%a %b %d %H:%M:%S %Y', time) . '] ' . join(', ', @lines) . "\n";
	});
	$self->helper(resourceUsageLog => sub { shift; return $resourceUsageLog->info(@_); });

	# Models
	$self->helper(newProblem => sub { my ($c, $args) = @_; Renderer::Model::Problem->new($c, $args) });

	# Helpers
	$self->helper(
		format => sub {
			my ($c, $rh_result) = @_;
			WeBWorK::FormatRenderedProblem::formatRenderedProblem($c, $rh_result);
		}
	);
	$self->helper(validateRequest => sub { my ($c, $options) = @_; Renderer::Controller::IO::validate($c, $options) });
	$self->helper(parseRequest => sub { my $c = shift; Renderer::Controller::Render::parseRequest($c) });
	$self->helper(
		croak => sub {
			my ($c, $exception, $depth) = @_;
			Renderer::Controller::Render::croak($c, $exception, $depth);
		}
	);
	$self->helper(logID => sub { my $c = shift; $c->req->request_id });
	$self->helper(
		exception => sub {
			my ($c, $message, $status, %data) = @_;
			Renderer::Controller::Render::exception($c, $message, $status, %data);
		}
	);

	# Routes
	# baseURL is the root at which the renderer is listening.
	my $r = $self->routes->under($self->config->{baseURL});

	$r->any('/render-api')->to('render#problem');
	$r->any('/render-ptx')->to('render#render_ptx');
	$r->any('/health' => sub { shift->rendered(200) });

	# Enable problem editor & OPL browser -- NOT recommended for production environment!
	supplementalRoutes($r) if ($self->mode eq 'development' || $self->config('FULL_APP_INSECURE'));

	# Static file routes
	$r->any('/pg_files/CAPA_Graphics/*static')->to('StaticFiles#CAPA_graphics_file')->name('capaFile');
	$r->any('/pg_files/tmp/*static')->to('StaticFiles#temp_file')->name('pgTempFile');
	$r->any('/pg_files/*static')->to('StaticFiles#pg_file')->name('pgFile');
	$r->any('/*static')->to('StaticFiles#public_file')->name('publicFile');

	return;
}

sub supplementalRoutes {
	my $r = shift;

	# UI
	$r->any('/')->to('pages#twocolumn');
	$r->any('/opl')->to('pages#oplUI');

	# Testing
	$r->any('/die'     => sub { die "what did you expect, flowers?" });
	$r->any('/timeout' => sub { timeout(@_) });

	# JWT Convenience
	$r->any('/render-api/jwt')->to('render#jwtFromRequest');
	$r->any('/render-api/jwe')->to('render#jweFromRequest');

	# Library Actions
	$r->any('/render-api/tap')->to('IO#raw');
	$r->post('/render-api/can')->to('IO#writer');
	$r->any('/render-api/cat')->to('IO#catalog');
	$r->any('/render-api/find')->to('IO#search');
	$r->post('/render-api/upload')->to('IO#upload');
	$r->delete('/render-api/remove')->to('IO#remove');
	$r->post('/render-api/clone')->to('IO#clone');
	$r->post('/render-api/tags')->to('IO#setTags');

	# ShowMeAnother Support Functions
	$r->post('/render-api/sma')->to('IO#findNewVersion');
	$r->post('/render-api/unique')->to('IO#findUniqueSeeds');
}

sub timeout {
	my $c  = shift;
	my $tx = $c->render_later->tx;
	Mojo::IOLoop->timer(
		2 => sub {
			$tx = $tx;    # prevent $tx from going out of scope
			$c->rendered(200);
		}
	);
}

sub sanitizeHostURLs {
	my $self = shift;

	$self->config->{SITE_HOST} =~ s!/$!!;

	# Set an absolute base href for asset urls under iframe embedding.
	if ($self->config->{baseURL} =~ m!^https?://!) {
		# This should only be used by MITM sites when proxying renderer assets.
		my $baseURL = $self->config->{baseURL} =~ m!/$! ? $self->config->{baseURL} : $self->config->{baseURL} . '/';
		$self->defaults->{baseHREF} = Mojo::URL->new($baseURL);

		# Do NOT use the proxy address for the router!
		$self->config->{baseURL} = '';
	} elsif ($self->config->{baseURL} =~ m!\S!) {
		# Ensure baseURL starts with a slash but doesn't end with a slash.
		$self->config->{baseURL} = '/' . $self->config->{baseURL} unless $self->config->{baseURL} =~ m!^/!;
		$self->config->{baseURL} =~ s!/$!!;

		# base href must end in a slash when not hosting at the root.
		$self->defaults->{baseHREF} = Mojo::URL->new($self->config->{SITE_HOST})->path($self->config->{baseURL} . '/');
	} else {
		# no proxy and service is hosted at the root of SITE_HOST
		$self->defaults->{baseHREF} = Mojo::URL->new($self->config->{SITE_HOST});
	}

	if ($self->config->{formURL} =~ m!\S!) {
		# this should only be used by MITM
		$self->defaults->{formURL} = Mojo::URL->new($self->config->{formURL});
		die '*** [CONFIG] if provided, formURL must be absolute'
			unless $self->defaults->{formURL}->is_abs;
	} else {
		# if using MITM proxy base href + renderer api not at SITE_HOST root
		# provide form url as absolute SITE_HOST/extension/render-api
		$self->defaults->{formURL} =
			Mojo::URL->new($self->config->{SITE_HOST})->path($self->config->{baseURL} . '/render-api');
	}
}

1;
