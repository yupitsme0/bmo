# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::REST::CGI;

use strict;

use base qw(Bugzilla::CGI);

use Bugzilla;

use CGI;

sub new {
    my ($invocant, @args) = @_;
    my $class = ref($invocant) || $invocant;
    my $self = $class->SUPER::new(@args);
    $self->path_info(CGI->new->path_info);
    return $self;
}

1;
