# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::AutoLand::Constants;

use strict;

use base qw(Exporter);

our @EXPORT = qw(
    VALID_STATUSES 
);

use constant VALID_STATUSES => qw(
    waiting 
    running
    failed
    success
);

1;
