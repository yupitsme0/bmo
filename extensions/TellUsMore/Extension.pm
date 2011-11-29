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
# The Original Code is the Bugzilla TellUsMore Extension.
#
# The Initial Developer of the Original Code is the Mozilla Foundation.
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Byron Jones <glob@mozilla.com>

package Bugzilla::Extension::TellUsMore;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Extension::TellUsMore::Constants;
use Bugzilla::Extension::TellUsMore::VersionMirror qw(update_versions);
use Bugzilla::Extension::TellUsMore::Process;

use Scalar::Util;

our $VERSION = '1';

#
# initialisation
#

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    $args->{'schema'}->{'tell_us_more'} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            token => {
                TYPE => 'varchar(16)',
                NOTNULL => 1,
            },
            mail => {
                TYPE => 'varchar(255)',
                NOTNULL => 1,
            },
            creation_ts => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            content => {
                TYPE => 'LONGBLOB',
                NOTNULL => 1,
            },
        ],
    };
}

sub install_before_final_checks {
    my ($self, $args) = @_;
    # trigger a version sync during checksetup
    my $mirror = Bugzilla::Extension::TellUsMore::VersionMirror->new();
    if (!$mirror->check_setup(1)) {
        print $mirror->setup_error, "\n";
        return;
    }
    $mirror->refresh();
}

#
# version mirror hooks
#

sub object_end_of_create {
    my ($self, $args) = @_;
    my $object = $args->{'object'};

    if ($self->is_version($object)) {
        $self->_mirror->created($object);
    }
}

sub object_end_of_update {
    my ($self, $args) = @_;
    my $object = $args->{'object'};

    if ($self->is_version($object)) {
        $self->_mirror->updated($args->{'old_object'}, $object);
    }
}

sub object_before_delete {
    my ($self, $args) = @_;
    my $object = $args->{'object'};

    if ($self->is_version($object)) {
        $self->_mirror->deleted($object);
    }
}

sub is_version {
    my ($self, $object) = @_;
    my $class = Scalar::Util::blessed($object);
    return $class eq 'Bugzilla::Version';
}

sub _mirror {
    my ($self) = @_;
    $self->{'mirror'} ||= Bugzilla::Extension::TellUsMore::VersionMirror->new();
    return $self->{'mirror'};
}

#
# token validation page
#

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{'page_id'};

    if ($page eq 'tellusmore.html') {
        my $process = Bugzilla::Extension::TellUsMore::Process->new();
        my ($bug, $is_new_user) = $process->execute(Bugzilla->input_params->{'token'});
        my $vars = $args->{'vars'};
        if ($bug) {
            $vars->{'bug'} = $bug;
            $vars->{'is_new_user'} = $is_new_user;
        } else {
            $vars->{'error'} = $process->error;
        }
    }
}

#
# web service
#

sub webservice {
    my ($self,  $args) = @_;
    my $dispatch = $args->{dispatch};
    $dispatch->{TellUsMore} = "Bugzilla::Extension::TellUsMore::WebService";
}

__PACKAGE__->NAME;
