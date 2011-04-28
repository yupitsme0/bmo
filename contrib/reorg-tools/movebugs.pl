#!/usr/bin/perl -w
use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;

Bugzilla->usage_mode(USAGE_MODE_CMDLINE);

if (scalar @ARGV < 4) {
    die <<USAGE;
Usage: movebugs.pl <old-product> <old-component> <new-product> <new-component>

Eg. movebugs.pl mozilla.org bmo bugzilla.mozilla.org admin
Will move all bugs in the mozilla.org:bmo component to the
bugzilla.mozilla.org:admin component.

Important: You must make sure the milestones and versions of the bugs in the
component are available in the new product. See syncmsandversions.pl.
USAGE
}

my ($old_product, $old_component, $new_product, $new_component) = @ARGV;

my $dbh = Bugzilla->dbh;

my $old_product_id = $dbh->selectrow_array(
    "SELECT id FROM products WHERE name=?",
    undef, $old_product);
$old_product_id
    or die "Can't find product ID for '$old_product'.\n";

my $old_component_id = $dbh->selectrow_array(
    "SELECT id FROM components WHERE name=? AND product_id=?",
    undef, $old_component, $old_product_id);
$old_component_id
    or die "Can't find component ID for '$old_component'.\n";

my $new_product_id = $dbh->selectrow_array(
    "SELECT id FROM products WHERE name=?",
    undef, $new_product);
$new_product_id
    or die "Can't find product ID for '$new_product'.\n";

my $new_component_id = $dbh->selectrow_array(
    "SELECT id FROM components WHERE name=? AND product_id=?",
    undef, $new_component, $new_product_id);
$new_component_id
    or die "Can't find component ID for '$new_component'.\n";

my $product_field_id = $dbh->selectrow_array(
    "SELECT id FROM fielddefs WHERE name = 'product'");
$product_field_id
    or die "Can't find field ID for 'product' field\n";
my $component_field_id = $dbh->selectrow_array(
    "SELECT id FROM fielddefs WHERE name = 'component'");
$component_field_id
    or die "Can't find field ID for 'component' field\n";

my $user_id = $dbh->selectrow_array(
    "SELECT userid FROM profiles WHERE login_name='nobody\@mozilla.org'");
$user_id
    or die "Can't find user ID for 'nobody\@mozilla.org'\n";

$dbh->bz_start_transaction();

# build list of bugs
my $ra_ids = $dbh->selectcol_arrayref(
    "SELECT bug_id FROM bugs WHERE product_id=? AND component_id=?",
    undef, $old_product_id, $old_component_id);
my $bug_count = scalar @$ra_ids;
$bug_count
    or die "No bugs were found in '$old_component'\n";
my $where_sql = 'bug_id IN (' . join(',', @$ra_ids) . ')';

print "Moving $bug_count bugs from $old_product:$old_component to $new_product:$new_component\n";

# update bugs
$dbh->do(
    "UPDATE bugs SET product_id=?, component_id=? WHERE $where_sql",
    undef, $new_product_id, $new_component_id);

# touch bugs 
$dbh->do("UPDATE bugs SET delta_ts=NOW() WHERE $where_sql");
$dbh->do("UPDATE bugs SET lastdiffed=NOW() WHERE $where_sql");

# update bugs_activity
$dbh->do(
    "INSERT INTO bugs_activity(bug_id, who, bug_when, fieldid, removed, added) 
          SELECT bug_id, ?, delta_ts, ?, ?, ?  FROM bugs WHERE $where_sql",
    undef,
    $user_id, $product_field_id, $old_product, $new_product);
$dbh->do(
    "INSERT INTO bugs_activity(bug_id, who, bug_when, fieldid, removed, added) 
          SELECT bug_id, ?, delta_ts, ?, ?, ?  FROM bugs WHERE $where_sql",
    undef,
    $user_id, $component_field_id, $old_component, $new_component);

$dbh->bz_commit_transaction();

