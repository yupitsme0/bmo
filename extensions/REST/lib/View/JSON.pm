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

package Bugzilla::Extension::REST::View::JSON;

use strict;

use base qw(Bugzilla::Extension::REST::View);

use Bugzilla;

use JSON;

sub view {
    my ($self, $data) = @_;
    my $json = JSON->new->utf8;
    $json->allow_blessed(1);
    $json->convert_blessed(1);
    # This may seem a little backwards,  but what this really means is
    # "don't convert our utf8 into byte strings,  just leave it as a
    # utf8 string."
    $json->utf8(0) if Bugzilla->params->{'utf8'};
    return $json->allow_nonref->encode($data); 
}

1;
