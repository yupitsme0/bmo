#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Mozilla Corporation.
# Portions created by the Initial Developer are Copyright (C) 2008
# Mozilla Corporation. All Rights Reserved.
#
# Contributor(s): Mark Smith <mark@mozilla.com>

use strict;
use lib '.';
use Bugzilla;
use Bugzilla::Error;
use Getopt::Long;

# get options
my %opts = ( foreground => 0, debug => 0, help => 0 );
GetOptions( 'foreground' => \$opts{foreground},
            'debug' => \$opts{debug},
            'help' => \$opts{help}, ) or help();
help() if $opts{help};

$::DEBUG = $opts{debug};

if ($::DEBUG && ! $opts{foreground}) {
    print "[$$] --debug implies --foreground ...\n";
    $opts{foreground} = 1;
}

################################################################################
## Main functionality
################################################################################

# initialize job queue and make sure it's a schwartz queue
my $sch;
my $jq = Bugzilla->job_queue();
ThrowCodeError('theschwartz_not_configured')
    unless ref $jq eq 'Bugzilla::JobQueue::TheSchwartz' &&
           ($sch = $jq->schwartz_object);

# this is what we can do; if you add more workers then you can
# extend this and add more items here if you want
$sch->can_do('Bugzilla::TheSchwartz::Mailer');

# daemonize if appropriate
daemonize() unless $opts{foreground};

# control never returns from here
print "[$$] Shuffling off to wait for work...\n"
    if $::DEBUG;
$sch->work;

################################################################################
## Helper subs
################################################################################

sub help {
    die <<EOF;
$0 usage:

    --foreground    Run in the foreground; i.e., do not daemonize

    --debug         Enable debugging output

    --help          Show this help

When this is run, we will begin connecting to the configured Schwartz database
and start processing jobs.

To stop processing jobs, kill the process.
EOF
}

sub daemonize {
    my ( $pid, $sess_id, $i );

    print "[$$] Daemonizing...\n" if $opts{debug};

    # Fork and exit parent
    if ($pid = fork) { exit 0; }

    # Detach ourselves from the terminal
    die "Cannot detach from controlling terminal"
        unless $sess_id = POSIX::setsid();

    # Prevent possibility of acquiring a controlling terminal
    $SIG{'HUP'} = 'IGNORE';
    if ($pid = fork) { exit 0; }

    # Change working directory
    chdir "/";

    # Clear file creation mask
    umask 0;

    # Close open file descriptors
    close(STDIN);
    close(STDOUT);
    close(STDERR);

    # Reopen stderr, stdout, stdin to /dev/null
    open(STDIN,  "+>/dev/null");
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");
}

################################################################################
## UNWRAPPERS / SMALL WORKERS                                                 ##
##                                                                            ##
## These are here to handle things in the way TheSchwartz likes to work.      ##
## Basically we create mini-workers that only call through to the Bugzilla    ##
## workers that actually do the work required to get something done.          ##
##                                                                            ##
## These should never do any real work.  If they do, then something is wrong  ##
## and you should probably move the functionality somewhere more apropros...  ##
################################################################################

package Bugzilla::TheSchwartz::Mailer;

use Bugzilla::Mailer::Queue;
use TheSchwartz::Worker;
use base 'TheSchwartz::Worker';

sub work {
    my ($class, $job) = @_;

    print "[$$] Bugzilla::TheSchwartz::Mailer() got job\n"
        if $::DEBUG;

    my $rv = Bugzilla::Mailer::Queue->process_message( %{ $job->arg || {} } );

    print "[$$] Bugzilla::TheSchwartz::Mailer() job returned " . ($rv || 'undef') . "\n"
        if $::DEBUG;

    $job->failed unless $rv;
    $job->completed;
}

sub grab_for { 300 }
sub keep_exit_status_for { 0 }
sub max_retries { 10 }
sub retry_delay { (10, 30, 60, 300, 600, 3600, 2*3600, 8*3600, 24*3600, 48*3600)[$_[1]] }

