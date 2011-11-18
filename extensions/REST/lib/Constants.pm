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

package Bugzilla::Extension::REST::Constants;
use strict;
use base qw(Exporter);
our @EXPORT = qw(
    STATUS_OK
    STATUS_CREATED
    STATUS_ACCEPTED
    STATUS_NO_CONTENT
    STATUS_MULTIPLE_CHOICES
    STATUS_BAD_REQUEST
    STATUS_NOT_FOUND
    STATUS_GONE
    ACCEPT_CONTENT_TYPES
);

use constant STATUS_OK               => 200;
use constant STATUS_CREATED          => 201;
use constant STATUS_ACCEPTED         => 202;
use constant STATUS_NO_CONTENT       => 204;
use constant STATUS_MULTIPLE_CHOICES => 300;
use constant STATUS_BAD_REQUEST      => 400;
use constant STATUS_NOT_FOUND        => 404;
use constant STATUS_GONE             => 410;

use constant ACCEPT_CONTENT_TYPES => (
    'text/html', 
    'application/json', 
    'application/javascript'
);

1;
