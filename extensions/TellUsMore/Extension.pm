# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TellUsMore;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Extension::TellUsMore::Constants;
use Bugzilla::Extension::TellUsMore::VersionMirror qw(update_versions);
use Bugzilla::Extension::TellUsMore::Process;

use Bugzilla::Constants;
use Bugzilla::Util qw(url_quote);
use Digest::MD5 qw(md5_hex);
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

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{panel_modules};
    $modules->{TellUsMore} = "Bugzilla::Extension::TellUsMore::Params";
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
        my $url;
        if ($bug) {
            $url = sprintf(RESULT_URL_SUCCESS, url_quote($bug->id), ($is_new_user ? '1' : '0'));
        } else {
            my $shared_secret = Bugzilla->params->{'tell_us_more_shared_secret'};
            my $error = clean_error($process->error);
            my $checksum = md5_hex($shared_secret . $error);
            $url = sprintf(RESULT_URL_FAILURE, url_quote($error), url_quote($checksum));
        }

        print Bugzilla->cgi->redirect($url);
        exit;
    }
}

# removes stacktrace and "at /some/path ..." from errors
sub clean_error {
    my ($error) = @_;
    foreach my $path (bz_locations->{'extensionsdir'}, '/loader/0x', '/usr/share/perl5/') {
        $error = $1 if $error =~ /^(.+?) at \Q$path/s;
    }
    $error =~ s/(^\s+|\s+$)//g;
    return $error;
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
