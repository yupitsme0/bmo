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
#

package Bugzilla::JobQueue;

use strict;

use Bugzilla::Error;
use Bugzilla::JobQueue::TheSchwartz;

sub new {
    my $class = shift;

    # for now, just assume TheSchwartz job queue; this should be
    # expanded to support an options panel for selecting a job queueing
    # system ... but there's only one for now :-)

    my $self = {};
    bless $self, "Bugzilla::JobQueue::TheSchwartz";

    $self->init;

    return $self;
}

1;

__END__

=head1 NAME

Bugzilla::JobQueue - Interface between Bugzilla and some random job queue system

=head1 SYNOPSIS

 use Bugzilla;

 my $obj = Bugzilla->job_queue();
 $obj->insert('send_mail', ( msg => $message ));

=head1 DESCRIPTION

Certain tasks should not be done syncronously.  The job queue system allows
Bugzilla to use some sort of service to schedule jobs to happen asyncronously.

=head2 Inserting a Job

See the synopsis above for an easy to follow example on how to insert a
job into the queue.  Give it a name and some arguments and the job will
be sent away to be done later.
