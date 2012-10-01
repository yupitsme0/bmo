# License,  v. 2.0. If a copy of the MPL was not distributed with this
# file,  You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",  as
# defined by the Mozilla Public License,  v. 2.0.

use strict;

use Cwd 'abs_path';
use File::Basename;
BEGIN {
    my $root = abs_path(dirname(__FILE__) . '/../..');
    chdir($root);
}
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;

sub usage() {
    print <<USAGE;
Usage: moveversion.pl <product> <oldversion> <newversion> <doit>

E.g.: moveversion.pl ReplicationEngine 1.0 2.0 doit
will move the version "1.0" from the product "ReplicationEngine"
to the version "2.0".

Pass in a true value for "doit" to make the database changes permament.
USAGE

    exit(1);
}

#############################################################################
# MAIN CODE
#############################################################################

# This is a pure command line script.
Bugzilla->usage_mode(USAGE_MODE_CMDLINE);

if (scalar @ARGV < 3) {
    usage();
    exit();
}

my ($product, $oldversion, $newversion, $doit) = @ARGV;

if ($oldversion eq $newversion) {
    print "Versions are the same. Why are you running this script again?\n";
    exit(1);
}

my $dbh = Bugzilla->dbh;

$dbh->{'AutoCommit'} = 0 unless $doit; # Turn off autocommit by default

# Find product IDs
my $prodid = $dbh->selectrow_array("SELECT id FROM products WHERE name = ?",
                                      undef, $product);
if (!$prodid) {
    print "Can't find product ID for '$product'.\n";
    exit(1);
}

# Verify old version
my $oldver = $dbh->selectrow_array("SELECT value FROM versions
                                    WHERE value = ? AND product_id = ?",
                                   undef, $oldversion, $prodid);
if (!$oldver) {
    print "Can't find version for '$oldversion' in product " .
          "'$product'.\n";
#    exit(1);
}

# Verify new version
my $newver = $dbh->selectrow_array("SELECT value FROM versions
                                    WHERE value = ? AND product_id = ?",
                                   undef, $newversion, $prodid);
if (!$newver) {
    print "Can't find version for '$newversion' in product " .
          "'$product'.\n";
    exit(1);
}

my $verfieldid = $dbh->selectrow_array("SELECT id FROM fielddefs 
                                         WHERE name = 'version'");
if (!$verfieldid) {
    print "Can't find field ID for 'version' field!\n";
    exit(1);
}

# Find user id for nobody@mozilla.org
my $user_id = $dbh->selectrow_array(
    "SELECT userid FROM profiles WHERE login_name='nobody\@mozilla.org'");
$user_id
    or die "Can't find user ID for 'nobody\@mozilla.org'\n";

# Build affected bug list
my $bugs = $dbh->selectcol_arrayref(
    "SELECT bug_id FROM bugs WHERE product_id = ? AND version = ?",
    undef, $prodid, $oldversion);
my $bug_count = scalar @$bugs;
$bug_count
    or die "No bugs were found in '$product / $oldversion'\n";

# confirmation
print <<EOF;
About to move the version from 
From '$product / $oldversion'
To '$product / $newversion'
for $bug_count bugs ...

Press <Ctrl-C> to stop or <Enter> to continue...
EOF
getc();

print "Moving version from '$product / $oldversion to '$product / $newversion' ...\n\n";
$dbh->bz_start_transaction() if $doit;

my $where_sql = 'bug_id IN (' . join(',', @$bugs) . ')';

# update bugs
$dbh->do("UPDATE bugs SET version = ? WHERE $where_sql",
         undef, $newversion);

# touch bugs
$dbh->do("UPDATE bugs SET delta_ts = NOW() WHERE $where_sql");
$dbh->do("UPDATE bugs SET lastdiffed = NOW() WHERE $where_sql");

# update bugs_activity
$dbh->do(
    "INSERT INTO bugs_activity (bug_id, who, bug_when, fieldid, removed, added) 
          SELECT bug_id, ?, delta_ts, ?, ?, ?  FROM bugs WHERE $where_sql",
    undef,
    $user_id, $verfieldid, $oldversion, $newversion);

$dbh->bz_commit_transaction() if $doit;

exit(0);
