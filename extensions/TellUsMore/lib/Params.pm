# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TellUsMore::Params;

use strict;
use warnings;

use Bugzilla::Config::Common;

our $sortkey = 1600;

sub get_param_list {
    my ($class) = @_;
    return ({
        name => 'tell_us_more_shared_secret',
        type => 't',
        default => '',
    });
}

1;
