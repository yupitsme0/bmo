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

package Bugzilla::Extension::REST::View::HTML;

use strict;

use base qw(Bugzilla::Extension::REST::View);

use Bugzilla::Extension::REST::Util qw(stringify_json_objects);

use YAML::Syck;

sub view {
    my ($self, $data) = @_;
    stringify_json_objects($data);
    my $content = "<html><title>Bugzilla::REST::API</title><body>" .
                  "<pre>" . Dump($data) . "</pre></body></html>";
    return $content;
}

1;
