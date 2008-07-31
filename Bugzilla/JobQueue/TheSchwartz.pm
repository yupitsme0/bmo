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

package Bugzilla::JobQueue::TheSchwartz;

use strict;
use base 'Bugzilla::JobQueue';

use Bugzilla::Error;

# initializer called when we need to connect to TheSchwartz
sub init {
    my $self = shift;

    return if $self->{schwartz_obj};

    my ($dsn, $user, $pass) =
        map { Bugzilla->localconfig->{"schwartz_db_$_"} }
            qw(dsn user pass);

    my $rv = eval "use TheSchwartz; 1;";

    ThrowCodeError('theschwartz_not_configured')
        unless $dsn && $user && $rv;

    $self->{schwartz_obj} = TheSchwartz->new(
        databases => [
            {
                dsn => $dsn,
                user => $user,
                pass => $pass,
            }
        ]
    );

    return $self;
}

sub schwartz_object {
    my $self = shift;

    return $self->{schwartz_obj};
}

# inserts a job into the queue to be processed and returns immediately
sub insert {
    my ($self, $job, %args) = @_;

    ThrowCodeError('theschwartz_not_configured')
        unless $self->{schwartz_obj};

    my $mapped = $self->_map_job_type($job);
    ThrowCodeError('theschwartz_no_job_mapping', { job => $job })
        unless $mapped;

    $self->{schwartz_obj}->insert($mapped, \%args);

    return 1;
}

# TheSchwartz requires job names to basically be the class that is
# going to be processing them.  so we map internal Bugzilla job
# names to that class name.
sub _map_job_type {
    return {
        send_mail => 'Bugzilla::TheSchwartz::Mailer',
    }->{$_[1]};
}

1;

__END__

=head1 NAME

Bugzilla::JobQueue::TheSchwartz - Interface between Bugzilla and TheSchwartz

=head1 SYNOPSIS

 use Bugzilla;

 my $obj = Bugzilla->job_queue();
 $obj->insert('send_mail', { msg => $message });

=head1 DESCRIPTION

TheSchwartz is a reliable job processing and management system that enables
easily inserting and processing jobs in a variety of ways.  Portions of
Bugzilla lend themselves to being parallelized, and TheSchwartz is a good
way to do this kind of work.

=head2 Inserting a Job

See the synopsis above for an easy to follow example on how to insert a
job into the queue.  Give it a name and some arguments and the job will
be sent away to be done later.

In reality, this documentation should be moved up a level, and this doc page
should talk about configuring TheSchwartz.  I'll try to do that...
