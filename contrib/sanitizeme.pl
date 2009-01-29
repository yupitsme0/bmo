#!/usr/bin/perl -wT
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
# The Initial Developer of the Original Code is the Mozilla
# Corporation. Portions created by Mozilla are
# Copyright (C) 2006 Mozilla Foundation. All Rights Reserved.
#
# Contributor(s): Myk Melez <myk@mozilla.org>
#                 Alex Brugh <alex@cs.umn.edu>
#                 Dave Miller <justdave@mozilla.com>

use strict;

use lib qw(.);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;

my $dbh = Bugzilla->dbh;

# This SQL is designed to sanitize a copy of a Bugzilla database so that it 
# doesn't contain any information that can't be viewed from a web browser by
# a user who is not logged in.                                              

# Last validated against Bugzilla version 3.0.x

sub delete_product {
    # This sub really should be Bugzilla::Product->remove_from_db(),
    # but that didn't exist yet at the time of writing, so I had to
    # duplicate code from editproducts.cgi instead
    my $product = shift;

    if ($product->bug_count) {
        foreach my $bug_id (@{$product->bug_ids}) {
            my $bug = new Bugzilla::Bug($bug_id);
            $bug->remove_from_db();
        }
    }

    my $comp_ids = $dbh->selectcol_arrayref('SELECT id FROM components
                                             WHERE product_id = ?',
                                             undef, $product->id);

    $dbh->do('DELETE FROM component_cc WHERE component_id IN
              (' . join(',', @$comp_ids) . ')') if scalar(@$comp_ids);

    $dbh->do("DELETE FROM components WHERE product_id = ?",
             undef, $product->id);

    $dbh->do("DELETE FROM versions WHERE product_id = ?",
             undef, $product->id);

    $dbh->do("DELETE FROM milestones WHERE product_id = ?",
             undef, $product->id);

    $dbh->do("DELETE FROM group_control_map WHERE product_id = ?",
             undef, $product->id);

    $dbh->do("DELETE FROM flaginclusions WHERE product_id = ?",
             undef, $product->id);

    $dbh->do("DELETE FROM flagexclusions WHERE product_id = ?",
             undef, $product->id);

    $dbh->do("DELETE FROM products WHERE id = ?",
             undef, $product->id);
}

# Delete all non-public products, and all data associated with them
my @products = Bugzilla::Product->get_all();
my $mandatory = CONTROLMAPMANDATORY;
foreach my $product (@products) {
    # if there are any mandatory groups on the product, nuke it and
    # everything associated with it (including the bugs)
    my $mandatorygroups = $dbh->selectcol_arrayref("SELECT group_id FROM group_control_map WHERE product_id = ? AND (membercontrol = $mandatory)", undef, $product->id);
    if (0 < scalar(@$mandatorygroups)) {
        print "Deleting product '" . $product->name . "'...\n";
        delete_product($product);
    }
}

# Delete all data for bugs in security groups.
my $buglist = $dbh->selectall_arrayref("SELECT DISTINCT bug_id FROM bug_group_map");
print "Deleting bugs in security groups...\n";
$|=1; # disable buffering so the bug progress counter works
my $numbugs = scalar(@$buglist);
my $bugnum = 0;
foreach my $row (@$buglist) {
    my $bug_id = $row->[0];
    $bugnum++;
    print "\r$bugnum/$numbugs";
    my $bug = new Bugzilla::Bug($bug_id);
    $bug->remove_from_db();
}
print "\rDone            \n";

# Delete all 'insidergroup' comments and attachments
print "Deleting 'insidergroup' comments and attachments...\n";
$dbh->do("DELETE FROM longdescs WHERE isprivate = 1");
$dbh->do("DELETE attach_data FROM attachments JOIN attach_data ON attachments.attach_id = attach_data.id WHERE attachments.isprivate = 1");
$dbh->do("DELETE FROM attachments WHERE isprivate = 1");
$dbh->do("UPDATE bugs_fulltext SET comments = comments_noprivate");

# Delete all security groups.
print "Deleting security groups...\n";
$dbh->do("DELETE FROM bug_group_map");
$dbh->do("DELETE user_group_map FROM groups JOIN user_group_map ON groups.id = user_group_map.group_id WHERE groups.isbuggroup = 1");
$dbh->do("DELETE group_group_map FROM groups JOIN group_group_map ON (groups.id = group_group_map.member_id OR groups.id = group_group_map.grantor_id) WHERE groups.isbuggroup = 1");
$dbh->do("DELETE group_control_map FROM groups JOIN group_control_map ON groups.id = group_control_map.group_id WHERE groups.isbuggroup = 1");
$dbh->do("DELETE FROM groups where isbuggroup = 1");

# Remove sensitive user account data.
print "Deleting sensitive user account data...\n";
$dbh->do("UPDATE profiles SET cryptpassword = 'deleted'");
$dbh->do("DELETE FROM profiles_activity");
$dbh->do("DELETE FROM namedqueries");
$dbh->do("DELETE FROM tokens");
$dbh->do("DELETE FROM logincookies");

# Delete unnecessary attachment data.
print "Removing attachment data to preserve disk space...\n";
$dbh->do("UPDATE attach_data SET thedata = ''");

print "All done!\n";
exit;

