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

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;

sub usage() {
    print <<USAGE;
Usage: movecomponent.pl <oldproduct> <newproduct> <component>

E.g.: movecomponent.pl ReplicationEngine FoodReplicator SeaMonkey
will move the component "ReplicationEngine" from the product "FoodReplicator"
to the product "SeaMonkey".

Important: You must make sure the milestones and versions of the bugs in the
component are available in the new product. See syncmsandversions.pl.
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

my ($oldproduct, $newproduct, $component) = @ARGV;

my $dbh = Bugzilla->dbh;

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

# Find component ID
my $compid = $dbh->selectrow_array("SELECT id FROM components 
                                    WHERE name = ? AND product_id = ?",
                                   undef, $component, $oldprodid);
if (!$compid) {
    print "Can't find component ID for '$component' in product " .            
          "'$oldproduct'.\n";
    exit(1);
}

my $fieldid = $dbh->selectrow_array("SELECT id FROM fielddefs 
                                     WHERE name = 'product'");
if (!$fieldid) {
    print "Can't find field ID for 'product' field!\n";
    exit(1);
}

print "Moving '$component' from '$oldproduct' to '$newproduct'...\n\n";
#$dbh->bz_start_transaction();

# Bugs table
$dbh->do("UPDATE bugs SET product_id = ? WHERE component_id = ?", 
         undef,
         ($newprodid, $compid));

# Flags tables
$dbh->do("UPDATE flaginclusions SET product_id = ? WHERE component_id = ?", 
         undef,
         ($newprodid, $compid));

$dbh->do("UPDATE flagexclusions SET product_id = ? WHERE component_id = ?", 
         undef,
         ($newprodid, $compid));

# Components
$dbh->do("UPDATE components SET product_id = ? WHERE id = ?", 
         undef,
         ($newprodid, $compid));

# Mark bugs as touched
# 
$dbh->do("UPDATE bugs SET delta_ts = NOW() 
          WHERE component_id = ?", undef, $compid);

# Update bugs_activity
my $userid = 1; # nobody@mozilla.org

$dbh->do("INSERT INTO bugs_activity(bug_id, who, bug_when, fieldid, removed,
                                    added) 
             SELECT bug_id, ?, delta_ts, ?, ?, ? 
             FROM bugs WHERE component_id = ?",
         undef,
         ($userid, $fieldid, $oldproduct, $newproduct, $compid));

#$dbh->bz_commit_transaction();

exit(0);

