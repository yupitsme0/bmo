#!/usr/bin/perl -w
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
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Gervase Markham <gerv@gerv.net>

# See also https://bugzilla.mozilla.org/show_bug.cgi?id=119569
#

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
Usage: moveversion.pl <oldproduct> <oldversion> <newproduct> <newversion> <doit>

E.g.: moveversion.pl ReplicationEngine 1.0 ReplicationEngine 2.0 doit
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

my ($oldproduct, $oldversion, $newproduct, $newversion, $doit) = @ARGV;

my $dbh = Bugzilla->dbh;

$dbh->{'AutoCommit'} = 0 unless $doit; # Turn off autocommit by default

# Find product IDs
my $oldprodid = $dbh->selectrow_array("SELECT id FROM products WHERE name = ?",
                                      undef, $oldproduct);
if (!$oldprodid) {
    print "Can't find product ID for '$oldproduct'.\n";
    exit(1);
}

my $newprodid = $dbh->selectrow_array("SELECT id FROM products WHERE name = ?",
                                      undef, $newproduct);
if (!$newprodid) {
    print "Can't find product ID for '$newproduct'.\n";
    exit(1);
}

# Verify old version
my $oldver = $dbh->selectrow_array("SELECT value FROM versions
                                    WHERE value = ? AND product_id = ?",
                                   undef, $oldversion, $oldprodid);
if (!$oldver) {
    print "Can't find version for '$oldversion' in product " .
          "'$oldproduct'.\n";
    exit(1);
}

# Verify new version
my $newver = $dbh->selectrow_array("SELECT value FROM versions
                                    WHERE value = ? AND product_id = ?",
                                   undef, $newversion, $newprodid);
if (!$newver) {
    print "Can't find version for '$newversion' in product " .
          "'$newproduct'.\n";
    exit(1);
}

my $prodfieldid = $dbh->selectrow_array("SELECT id FROM fielddefs 
                                          WHERE name = 'product'");
if (!$prodfieldid) {
    print "Can't find field ID for 'product' field!\n";
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
    undef, $oldprodid, $oldversion);
my $bug_count = scalar @$bugs;
$bug_count
    or die "No bugs were found in '$oldproduct / $oldversion'\n";

# confirmation
print <<EOF;
About to move the version from 
From '$oldproduct / $oldversion'
To '$newproduct / $newversion'
for $bug_count bugs ...

Press <Ctrl-C> to stop or <Enter> to continue...
EOF
getc();

print "Moving version from '$oldproduct / $oldversion to '$newproduct / $newversion' ...\n\n";
$dbh->bz_start_transaction() if $doit;

my $where_sql = 'bug_id IN (' . join(',', @$bugs) . ')';

# Update bugs
$dbh->do(
    "UPDATE bugs SET product_id = ?, version = ? WHERE $where_sql",
    undef, $newprodid, $newversion);

# touch bugs
$dbh->do("UPDATE bugs SET delta_ts = NOW() WHERE $where_sql");
$dbh->do("UPDATE bugs SET lastdiffed = NOW() WHERE $where_sql");

# update bugs_activity
if ($newproduct ne $oldproduct) {
    $dbh->do(
        "INSERT INTO bugs_activity (bug_id, who, bug_when, fieldid, removed, added)
              SELECT bug_id, ?, delta_ts, ?, ?, ?  FROM bugs WHERE $where_sql",
        undef,
        ($user_id, $prodfieldid, $oldproduct, $newproduct));
}

$dbh->do(
    "INSERT INTO bugs_activity (bug_id, who, bug_when, fieldid, removed, added) 
          SELECT bug_id, ?, delta_ts, ?, ?, ?  FROM bugs WHERE $where_sql",
    undef,
    $user_id, $verfieldid, $oldversion, $newversion);

$dbh->bz_commit_transaction() if $doit;

exit(0);
