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

our $VERSION = '1';

use Bugzilla::User;

sub bugmail_recipients {
    my ($self, $args) = @_;
    foreach my $user_id (keys %{$args->{recipients}}) {
        my $user = Bugzilla::User->new($user_id);
        my $filter = 1;
        my $ra_filters = Bugzilla::Extension::LimitedEmail::FILTERS;
        foreach my $re (@$ra_filters) {
            if ($user->email =~ $re) {
                $filter = 0;
                last;
            }
        }
        if ($filter) {
            delete $args->{recipients}{$user_id};
        }
    }
}

__PACKAGE__->NAME;
