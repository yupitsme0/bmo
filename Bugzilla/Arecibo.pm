# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.
#
# The Original Code is bugzilla.mozilla.org.
#
# The Initial Developer of the Original Code is the Mozilla Foundation.
# Portions created by the Initial Developer are Copyright (C) 2011 the Initial
# Developer. All Rights Reserved.
#
# Contributor(s):
#   byron jones <glob@mozilla.com>
#
# ***** END LICENSE BLOCK *****

package Bugzilla::Arecibo;

use strict;
use warnings;

use base qw(Exporter);
our @EXPORT = qw(
    arecibo_handle_error
    arecibo_generate_id
    arecibo_should_notify
);

use Apache2::Log;
use Apache2::SubProcess;
use Carp;
use Email::Date::Format 'email_gmdate';
use LWP::UserAgent;
use POSIX 'setsid';
use Sys::Hostname;

use Bugzilla::Error;
use Bugzilla::Util;

use constant CONFIG => {
    # arecibo servers
    production_server  => 'http://localhost/',
    development_server => 'http://amckay-arecibo.khan.mozilla.org/v/1/',

    # 'types' maps from the error message to types and priorities
    types => [
        {
            type  => 'the_schwartz',
            boost => -10,
            match => [
                qr/TheSchwartz\.pm/,
            ],
        },
        {
            type  => 'database_error',
            boost => -10,
            match => [
                qr/DBD::mysql/,
                qr/Can't connect to the database/,
            ],
        },
        {
            type  => 'patch_reader',
            boost => +5,
            match => [
                qr#/PatchReader/#,
            ],
        },
        {
            type  => 'uninitialized_warning',
            boost => 0,
            match => [
                qr/Use of uninitialized value/,
            ],
        },
    ],

    # 'codes' lists the code-errors which are sent to arecibo
    codes => [qw(
        bug_error
        chart_datafile_corrupt
        chart_dir_nonexistent
        chart_file_open_fail
        illegal_content_type_method
        jobqueue_insert_failed
        ldap_bind_failed
        mail_send_error
        template_error
        token_generation_error
    )],
};

our $_arecibo_server;
our $_hostname;

sub _arecibo_init {
    return if $_arecibo_server;

    my $urlbase = Bugzilla->params->{urlbase};
    if ($urlbase eq 'https://bugzilla.mozilla.org/' ||
        $urlbase eq 'https://bugzilla-stage.mozilla.org'
    ) {
        $_arecibo_server = CONFIG->{production_server};
    } else {
        $_arecibo_server = CONFIG->{development_server};
    }

    $_hostname = hostname();
}

sub arecibo_generate_id {
    return sprintf("%s.%s", (time), $$);
}

sub arecibo_should_notify {
    my $code_error = shift;
    return grep { $_ eq $code_error } @{CONFIG->{codes}};
}

sub arecibo_handle_error {
    my $class = shift;
    my @message = split(/\n/, shift);
    my $id = shift || arecibo_generate_id();

    _arecibo_init();

    my $is_error = $class eq 'error';
    if ($class ne 'error' && $class ne 'warning') {
        # it's a code-error
        return unless arecibo_should_notify($class);
        $is_error = 1;
    }

    # build traceback
    my $traceback;
    {
        local $Carp::MaxArgLen  = 256;
        local $Carp::MaxArgNums = 0;
        local $Carp::CarpInternal{'Bugzilla::Error'}   = 1;
        local $Carp::CarpInternal{'Bugzilla::Arecibo'} = 1;
        $traceback = Carp::longmess();
    }

    # strip timestamp
    foreach my $line (@message) {
        $line =~ s/^\[[^\]]+\] //;
    }

    # log to apache's error_log
    my $message = join(" ", map { trim($_) } grep { $_ ne '' } @message);
    $message .= " [#$id]";
    if ($ENV{MOD_PERL}) {
        if ($is_error) {
            Apache2::ServerRec::log_error($message);
        } else {
            Apache2::ServerRec::warn($message);
        }
    } else {
        print STDERR "$message\n";
    }

    # set the error type and priority from the message content
    $message = join("\n", grep { $_ ne '' } @message);
    my $type = '';
    my $priority = $class eq 'error' ? 3 : 10;
    foreach my $rh_type (@{CONFIG->{types}}) {
        foreach my $re (@{$rh_type->{match}}) {
            if ($message =~ $re) {
                $type = $rh_type->{type};
                $priority += $rh_type->{boost};
                last;
            }
        }
        last if $type ne '';
    }
    $type ||= $class;
    $priority = 1 if $priority < 1;
    $priority = 10 if $priority > 10;

    my $username = '';
    eval { $username = Bugzilla->user->login };

    my $data = [
        msg        => $message,
        priority   => $priority,
        server     => $_hostname,
        status     => '500',
        timestamp  => email_gmdate(),
        traceback  => $traceback,
        type       => $type,
        uid        => $id,
        url        => Bugzilla->cgi->self_url,
        user_agent => $ENV{HTTP_USER_AGENT},
        username   => $username,
    ];

    # fork then post
    $SIG{CHLD} = 'IGNORE';
    my $pid = fork();
    if (defined($pid) && $pid == 0) {
        # detach
        chdir('/');
        open(STDIN, '</dev/null');
        open(STDOUT, '>/dev/null');
        open(STDERR, '>/dev/null');
        setsid();

        # post to arecibo (ignore any errors)
        my $agent = LWP::UserAgent->new(
            agent   => 'bugzilla.mozilla.org',
            timeout => 10, # seconds
        );
        $agent->post($_arecibo_server, $data);

        CORE::exit(0);
    }
}

# lifted from Bugzilla::Error
sub _in_eval {
    my $in_eval = 0;
    for (my $stack = 1; my $sub = (caller($stack))[3]; $stack++) {
        last if $sub =~ /^ModPerl/;
        $in_eval = 1 if $sub =~ /^\(eval\)/;
    }
    return $in_eval;
}

BEGIN {
    require CGI::Carp;
    CGI::Carp::set_die_handler(sub {
        return if _in_eval();
        my $message = shift;
        eval { ThrowTemplateError($message) };
        if ($@) {
            print "Content-type: text/html\n\n";
            my $uid = arecibo_generate_id();
            arecibo_handle_error('error', $message, $uid);
            my $maintainer = html_quote(Bugzilla->params->{'maintainer'});
            $message = html_quote($message);
            $uid = html_quote($uid);
            print qq(
                <h1>Bugzilla has suffered an internal error</h1>
                <pre>$message</pre>
                The <a href="mailto:$maintainer">Bugzilla maintainers</a> have
                been notified of this error [#$uid].
            );
            exit;
        }
    });
    $main::SIG{__WARN__} = sub {
        return if _in_eval();
        arecibo_handle_error('warning', shift);
    };
}

1;
