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

package Bugzilla::Mailer::Queue;

use Bugzilla;
use Bugzilla::Mailer;

use strict;

# returns undef on error, 1 on success
sub process_message {
    my ($class, %args) = @_;

    return undef unless $args{msg};

    eval {
        MessageToMTA($args{msg}, 1);
    };

    return undef if $@;
    return 1;
}


1;

__END__

=head1 NAME

Bugzilla::Mailer::Queue - Worker module for sending emails

=head1 SYNOPSIS

 ... not written ...
 
=head1 DESCRIPTION

This module provides a way to handle sending emails.  Does the actual
work of sending the mail.  (Well, in this case, uses Bugzilla::Mailer...)
