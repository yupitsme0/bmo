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
# The Original Code is the REST Bugzilla Extension.
#
# The Initial Developer of the Original Code is Mozilla.
# Portions created by Mozilla are Copyright (C) 2011 Mozilla Corporation.
# All Rights Reserved.
#
# Contributor(s):
#   Dave Lawrence <dkl@mozilla.com>

use strict;

use lib qw(../../.. ../../../lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::WebService::Constants;
BEGIN {
    if (!Bugzilla->feature('jsonrpc')) {
        ThrowCodeError('feature_disabled', { feature => 'jsonrpc' });
    }
}
use Bugzilla::Extension::REST::Server;
Bugzilla->usage_mode(USAGE_MODE_JSON);
local @INC = (bz_locations()->{extensionsdir}, @INC);
my $server = Bugzilla::Extension::REST::Server->new;
$server->version('1.1');
$server->handle();
exit;
