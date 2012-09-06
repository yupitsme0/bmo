# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
# 
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
# 
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.
# 
# The Original Code is the OrangeFactor Bugzilla Extension;
# Derived from the Bugzilla Tweaks Addon.
# 
# The Initial Developer of the Original Code is the Mozilla Foundation.
# Portions created by the Initial Developer are Copyright (C) 2011 the Initial
# Developer. All Rights Reserved.
# 
# Contributor(s):
#   Johnathan Nightingale <johnath@mozilla.com>
#   Ehsan Akhgari <ehsan@mozilla.com>
#   Heather Arthur <harthur@mozilla.com>
#   Byron Jones <glob@mozilla.com>
#   David Lawrence <dkl@mozilla.com>
#
# ***** END LICENSE BLOCK *****

package Bugzilla::Extension::OrangeFactor;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::User::Setting;
use Bugzilla::Constants;
use Bugzilla::Attachment;

our $VERSION = '1.0';

sub template_before_process {
    my ($self, $args) = @_;
    my $file = $args->{'file'};
    my $vars = $args->{'vars'};

    my $user = Bugzilla->user;

    return unless $user && $user->id && $user->settings;
    return unless $user->settings->{'orange_factor'}->{'value'} eq 'on';

    # in the header we just need to set the var, to 
    # ensure the css and javascript get included
    if ($file eq 'bug/show-header.html.tmpl'
        || $file eq 'bug/edit.html.tmpl') {
        my $bug = exists $vars->{'bugs'} ? $vars->{'bugs'}[0] : $vars->{'bug'};
        if ($bug && $bug->status_whiteboard =~ /\[orange\]/) {
            $vars->{'orange_factor'} = 1;
        }
    }
}

sub install_before_final_checks {
    my ($self, $args) = @_;
    add_setting('orange_factor', ['on', 'off'], 'off');
}

__PACKAGE__->NAME;
