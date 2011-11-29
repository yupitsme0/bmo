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
# The Original Code is the Bugzilla TellUsMore Extension.
#
# The Initial Developer of the Original Code is the Mozilla Foundation.
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Byron Jones <glob@mozilla.com>

package Bugzilla::Extension::TellUsMore::Constants;

use strict;
use base qw(Exporter);

our @EXPORT = qw(
    TELL_US_MORE_LOGIN

    MAX_ATTACHMENT_COUNT
    MAX_ATTACHMENT_SIZE

    MAX_REPORTS_PER_MINUTE

    TARGET_PRODUCT
    SECURITY_GROUP

    DEFAULT_VERSION
    DEFAULT_COMPONENT

    MANDATORY_BUG_FIELDS
    OPTIONAL_BUG_FIELDS

    MANDATORY_ATTACH_FIELDS
    OPTIONAL_ATTACH_FIELDS

    TOKEN_EXPIRY_DAYS

    VERSION_SOURCE_PRODUCTS
    VERSION_TARGET_PRODUCT
);

use constant TELL_US_MORE_LOGIN => 'tellusmore@input.bugs';

use constant MAX_ATTACHMENT_COUNT => 2;
use constant MAX_ATTACHMENT_SIZE  => 512; # kilobytes

use constant MAX_REPORTS_PER_MINUTE => 2;

use constant TARGET_PRODUCT => 'Untriaged Bugs';
use constant SECURITY_GROUP => 'core-security';

use constant DEFAULT_VERSION => 'unspecified';
use constant DEFAULT_COMPONENT => 'General';

use constant MANDATORY_BUG_FIELDS => qw(
    creator
    description
    product
    summary
    user_agent
);

use constant OPTIONAL_BUG_FIELDS => qw(
    attachments
    creator_name
    restricted
    url
    version
);

use constant MANDATORY_ATTACH_FIELDS => qw(
    filename
    content_type
    content
);

use constant OPTIONAL_ATTACH_FIELDS => qw(
    description
);

use constant TOKEN_EXPIRY_DAYS => 7;

use constant VERSION_SOURCE_PRODUCTS => ('Firefox', 'Fennec');
use constant VERSION_TARGET_PRODUCT => 'Untriaged Bugs';

1;
