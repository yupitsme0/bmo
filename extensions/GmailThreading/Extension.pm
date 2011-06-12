# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.
#
# The Original Code is the GmailThreading Bugzilla Extension.
#
# The Initial Developer of the Original Code is The Mozilla Foundation.
# Portions created by the Initial Developer are Copyright (C) 2011 the Initial
# Developer. All Rights Reserved.
#
# Contributor(s):
#   Byron Jones <glob@mozilla.com>

package Bugzilla::Extension::GmailThreading;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::User::Setting;
use Bugzilla::Util;

use Encode qw(encode);

our $VERSION = '1';

sub mailer_before_send {
    my ($self, $args) = @_;
    my $header = $args->{email}->{header};

    # grab the recipient
    my $to = $header->header('to');

    # map to a login
    my $login = $to;
    my $email_suffix = Bugzilla->params->{emailsuffix};
    if ($email_suffix ne '') {
        $login =~ s/\Q$email_suffix\E$//;
    }

    # make a bugzilla user object
    my $user = Bugzilla::User->new({ name => $login })  
        or return;

    # check recipient's setting
    if ($user->settings->{gmail_threading}->{value} ne 'On') {
        return;
    }

    # strip 'New: ' prefix
    my $bug_word = template_var('terms')->{Bug};
    my $subject = $header->header('subject');
    $subject =~ s/^(\[$bug_word \d+\] )New: /$1/;

    # we need to re-encode the subject because Email::MIME decodes it
    if (Bugzilla->params->{'utf8'} && !utf8::is_utf8($subject)) {
        utf8::decode($subject);
    }
    # avoid excessive line wrapping done by Encode.
    local $Encode::Encoding{'MIME-Q'}->{'bpl'} = 998;
    $header->header_set('subject', encode('MIME-Q', $subject));
}

sub install_before_final_checks {
    my ($self, $args) = @_;
    add_setting('gmail_threading', ['On', 'Off'], 'Off');
}

__PACKAGE__->NAME;
