# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::AutoLand;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::Bug;
use Bugzilla::Attachment;
use Bugzilla::User;
use Bugzilla::Util qw(trick_taint diff_arrays);

our $VERSION = '0.01';

BEGIN {
    *Bugzilla::Bug::autoland_branches           = \&_autoland_branches;
    *Bugzilla::Attachment::autoland_checked     = \&_autoland_attachment_checked;
    *Bugzilla::Attachment::autoland_who         = \&_autoland_attachment_who;
    *Bugzilla::Attachment::autoland_status      = \&_autoland_attachment_status;
    *Bugzilla::Attachment::autoland_status_when = \&_autoland_attachment_status_when;
}

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    $args->{'schema'}->{'autoland_branches'} = {
        FIELDS => [
            bug_id => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
                REFERENCES => {
                    TABLE  => 'bugs',
                    COLUMN => 'bug_id',
                    DELETE => 'CASCADE'
                }
            },
            branches => {
                TYPE    => 'VARCHAR(255)',
                NOTNULL => 1
            }, 
        ],
    };

    $args->{'schema'}->{'autoland_attachments'} = {
        FIELDS => [
            attach_id => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                PRIMARYKEY => 1, 
                REFERENCES => {
                    TABLE  => 'attachments',
                    COLUMN => 'attach_id',
                    DELETE => 'CASCADE'
                },
            },
            who => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'profiles',
                    COLUMN => 'userid',
                },
            },
            status => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1
            }, 
            status_when => {
                TYPE    => 'DATETIME',
                NOTNULL => 1,
            },
        ],
    };
}

sub _autoland_branches {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'autoland_branches'} if $self->{'autoland_branches'};
    $self->{'autoland_branches'} 
        = $dbh->selectrow_array("SELECT branches FROM autoland_branches 
                                 WHERE bug_id = ?", undef, $self->id);
    return $self->{'autoland_branches'};
}

sub _autoland_attachment_checked {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'autoland_checked'} if exists $self->{'autoland_checked'};
    my $result = $dbh->selectrow_hashref("SELECT who, status, status_when 
                                            FROM autoland_attachments
                                           WHERE attach_id = ?", { Slice => {} }, $self->id);
    if ($result) {
        $self->{'autoland_checked'}     = 1;
        $self->{'autoland_who'}         = Bugzilla::User->new($result->{'who'});
        $self->{'autoland_status'}      = $result->{'status'};
        $self->{'autoland_status_when'} = $result->{'status_when'};
    }
    else {
        $self->{'autoland_checked'}     = 0;
        $self->{'autoland_who'}         = undef;
        $self->{'autoland_status'}      = undef;
        $self->{'autoland_status_when'} = undef;
    }
    return $self->{'autoland_checked'};
}

sub _autoland_attachment_who {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return undef if !$self->autoland_checked;
    return $self->{'autoland_who'};
}

sub _autoland_attachment_status {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return undef if !$self->autoland_checked;
    return $self->{'autoland_status'};
}

sub _autoland_attachment_status_when {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return undef if !$self->autoland_checked;
    return $self->{'autoland_status_when'};
}

sub object_end_of_update {
    my ($self, $args) = @_;
    my $object = $args->{'object'};
    my $user   = Bugzilla->user;
    my $dbh    = Bugzilla->dbh;
    my $cgi    = Bugzilla->cgi;
    my $params = Bugzilla->input_params;

    return if !$user->in_group('hg-try');

    if ($object->isa('Bugzilla::Bug')) {
        # First make any needed changes to the branches field
        my $bug_id = $object->bug_id;
        my $old_branches 
            = $dbh->selectrow_array("SELECT branches FROM autoland_branches 
                                     WHERE bug_id = ?", undef, $bug_id);
        my $new_branches = $cgi->param('autoland_branches') || '';
        trick_taint($new_branches);
        if (!$new_branches && $old_branches) {
            $dbh->do("DELETE FROM autoland_branches WHERE bug_id = ?",
                     undef, $bug_id);
        }
        elsif ($new_branches && !$old_branches) {
            $dbh->do("INSERT INTO autoland_branches (bug_id, branches)
                      VALUES (?, ?)", undef, $bug_id, $new_branches); 
        }
        elsif ($old_branches ne $new_branches) {
            $dbh->do("UPDATE autoland_branches SET branches = ? WHERE bug_id = ?",
                     undef, $new_branches, $bug_id);
        }

        # Next make any changes needed to each of the attachments.
        # 1. If an attachment is checked it has a row in the table, if
        # there is no row in the table it is not checked.
        # 2. Do not allow changes to checked state if status == 'running' or status == 'waiting'
        my $check_attachments = ref $params->{'defined_autoland_attachments'}
                                ? $params->{'defined_autoland_attachments'}
                                : [ $params->{'defined_autoland_attachments'} ];
        my $set_attachments   = ref $params->{'autoland_attachments'}
                                ? $params->{'autoland_attachments'}
                                : [ $params->{'autoland_attachments'} ];
        my ($removed_attachments) = diff_arrays($check_attachments, $set_attachments);
        foreach my $attachment (@{$object->attachments}) {
            next if !$attachment->ispatch;
            my $attach_id = $attachment->id;

            my $checked = (grep $_ == $attach_id, @$set_attachments) ? 1 : 0;
            my $unchecked = (grep $_ == $attach_id, @$removed_attachments) ? 1 : 0;
            my $old_checked = $dbh->selectrow_array("SELECT 1 FROM autoland_attachments
                                                     WHERE attach_id = ?", undef, $attach_id) || 0;

            next if $checked && $old_checked;

            if ($unchecked && $old_checked && $attachment->autoland_status =~ /^(failed|success)$/) {
                $dbh->do("DELETE FROM autoland_attachments WHERE attach_id = ?", undef, $attach_id);
            }
            elsif ($checked && !$old_checked) {
                $dbh->do("INSERT INTO autoland_attachments (attach_id, who, status, status_when) 
                          VALUES (?, ?, 'waiting', now())", undef, $attach_id, $user->id);
            }
        }

    }
}

sub template_before_process {
    my ($self, $args) = @_;
    my $file = $args->{'file'};
    my $vars = $args->{'vars'};

    # in the header we just need to set the var to ensure the css gets included
    if ($file eq 'bug/show-header.html.tmpl' && Bugzilla->user->in_group('hg-try') ) {
        $vars->{'autoland'} = 1;
    }
}

sub webservice {
    my ($self, $args) = @_;

    my $dispatch = $args->{dispatch};
    $dispatch->{AutoLand} = "Bugzilla::Extension::AutoLand::WebService";
}

__PACKAGE__->NAME;
