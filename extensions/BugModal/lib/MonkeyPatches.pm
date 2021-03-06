# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::BugModal::MonkeyPatches;
1;

package Bugzilla;
use strict;
use warnings;

use Bugzilla::User;

sub treeherder_user {
    return Bugzilla->process_cache->{treeherder_user} //=
        Bugzilla::User->new({ name => 'tbplbot@gmail.com', cache => 1 })
        || Bugzilla::User->new({ name => 'orangefactor@bots.tld', cache => 1 })
        || Bugzilla::User->new();
}

package Bugzilla::Bug;
use strict;
use warnings;

use Bugzilla::Attachment;

sub active_attachments {
    my ($self) = @_;
    return [] if $self->{error};
    return $self->{active_attachments} //= Bugzilla::Attachment->get_attachments_by_bug(
        $self, { exclude_obsolete => 1, preload => 1 });
}

1;

package Bugzilla::User;
use strict;
use warnings;

sub moz_nick {
    my ($self) = @_;
    if (!exists $self->{moz_nick}) {
        if ($self->name =~ /:?:(\S+?)\b/) {
            $self->{moz_nick} = $1;
        }
        elsif ($self->name) {
            $self->{moz_nick} = $self->name;
        }
        else {
            $self->login =~ /^([^\@]+)\@/;
            $self->{moz_nick} = $1;
        }
    }
    return $self->{moz_nick};
}

1;

package Bugzilla::Attachment;
use strict;
use warnings;

sub is_image {
    my ($self) = @_;
    return substr($self->contenttype, 0, 6) eq 'image/';
}

1;
