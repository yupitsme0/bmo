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
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Myk Melez <myk@mozilla.org>
#                 Gervase Markham <gerv@gerv.net>

use strict;

use lib qw(.);

use Bugzilla;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::Util;

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};

###############################################################################
# Begin Data/Security Validation
###############################################################################

# Check whether or not the user is currently logged in. 
Bugzilla->login();

my $bug_id = $cgi->param('id');
my $type = $cgi->param('type');
my $users = $cgi->param('users');
my $chfrom = $cgi->param('chfrom');
my $chto = $cgi->param('chto');

###############################################################################
# End Data/Security Validation
###############################################################################


my %activities;
if ($type eq 'user') {
    my %allusers;
    foreach my $u (split(/[,\s]/, $users)){
        my $matched_users = Bugzilla::User::match($u);
        foreach my $mu (@$matched_users) {
            $allusers{$mu->id} = $mu;
        }
    }

    if (!scalar(keys %allusers)) {
        ThrowUserError('no_user_match');
    }

    foreach my $user (values %allusers) {
        my %new_activity;

        ($new_activity{'operations'},
         $new_activity{'incomplete_data'},
         $new_activity{'hidden_changes'}) = $user->get_user_activity($chfrom, $chto);

        $activities{$user->id} = \%new_activity;
    }

    $vars->{'chfrom'} = $chfrom ? SqlifyDate($chfrom, 1) : '';
    $vars->{'chto'} = ($chto && lc($chto) ne 'now') ? SqlifyDate($chto, 1) : 'Now';

    $vars->{'match'} = $users;
    $vars->{'users'} = \%allusers;
}
else {
    ThrowCodeError("missing_bug_id") unless defined $bug_id;

    # Make sure the bug ID is a positive integer representing an existing
    # bug that the user is authorized to access.
    ValidateBugID($bug_id);

    my ($operations, $incomplete_data) =
        Bugzilla::Bug::GetBugActivity($bug_id);

    $activities{$bug_id} = {operations=> $operations,
                            incomplete_data => $incomplete_data};
    $vars->{'bug_id'} = $bug_id;
}
$vars->{'activities'} = \%activities;

print $cgi->header();

$template->process("bug/activity/show.html.tmpl", $vars)
  || ThrowTemplateError($template->error());
