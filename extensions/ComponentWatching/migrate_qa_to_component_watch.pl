# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

#!/usr/bin/perl

use strict;
use warnings;

use Cwd 'abs_path';
use File::Basename;
BEGIN {
    chdir(abs_path(dirname(__FILE__) . '/../..'));
}
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;

Bugzilla->usage_mode(USAGE_MODE_CMDLINE);

my $dbh = Bugzilla->dbh;

my $ra_component_ids = $dbh->selectcol_arrayref(<<EOF);
    SELECT c.id
      FROM components c
           INNER JOIN profiles u ON u.userid = c.initialqacontact
     WHERE u.login_name LIKE '%.bugs'
EOF
my $count = scalar @$ra_component_ids;

print <<EOF;
This script will migrate all .bugs QA contacts to the Component Watch
"watch user" field.

Number of components to update: $count

Press <Ctrl-C> to stop or <Enter> to continue...
EOF
getc();

print "Updating...\n";
$dbh->bz_start_transaction;

my $in = join(',', @$ra_component_ids);
$dbh->do(<<EOF);
    UPDATE components
       SET watch_user=initialqacontact
     WHERE id IN ($in)
EOF

$dbh->do(<<EOF);
    UPDATE components
       SET initialqacontact=NULL
     WHERE id IN ($in)
EOF

$dbh->bz_commit_transaction;
print "Done.\n";
