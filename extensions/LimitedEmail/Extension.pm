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
# The Original Code is the LimitedEmail Extension.
#
# The Initial Developer of the Original Code is the Mozilla Foundation
# Portions created by the Initial Developers are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Byron Jones <bjones@mozilla.com>

package Bugzilla::Extension::LimitedEmail;
use strict;
use base qw(Bugzilla::Extension);

our $VERSION = '2';

use Date::Format;
use Fcntl ':flock';
use FileHandle;

sub mailer_before_send {
    my ($self, $args) = @_;
    return if Bugzilla->params->{'urlbase'} eq 'https://bugzilla.mozilla.org/';
    my $email = $args->{email};
    my $header = $email->{header};

    my $blocked = '';
    if (!deliver_to($header->header('to'))) {
        $blocked = $header->header('to');
        $header->header_set(to => '');
    }

    my $fh = FileHandle->new(Bugzilla::Extension::LimitedEmail::MAIL_LOG, '>>');
    if (defined $fh) {
        flock($fh, LOCK_EX);
        print $fh sprintf(
            "[%s] %s%s : %s\n",
            time2str('%D %T', time),
            ($blocked eq '' ? '' : '(blocked) '),
            ($blocked eq '' ? $header->header('to') : $blocked),
            $header->header('subject')
        );
        close $fh;
    }
}

sub deliver_to {
    my $email = address_of(shift);
    my $ra_filters = Bugzilla::Extension::LimitedEmail::FILTERS;
    foreach my $re (@$ra_filters) {
        if ($email =~ $re) {
            return 1;
        }
    }
    return 0;
}

sub address_of {
    my $email = shift;
    return $email unless $email =~ /<([^>]+)>/;
    return $1;
}

__PACKAGE__->NAME;
