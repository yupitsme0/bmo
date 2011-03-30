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
# Contributor(s): Frédéric Buclin <LpSolit@gmail.com>
#                 David Miller <justdave@mozilla.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Field;

die "Please provide a field name.\n" if !defined $::ARGV[0];

my $name = $::ARGV[0];
my $type = FIELD_TYPE_SINGLE_SELECT;

Bugzilla::Field->create({
    name        => $name,
    description => 'Please give me a description!',
    type        => $type,
    mailhead    => 0,
    enter_bug   => 1,
    obsolete    => 1,
    custom      => 1,
    buglist     => ($type == FIELD_TYPE_MULTI_SELECT) ? 0 : 1,
});

print "Done!\n";
print "Please visit https://bugzilla.mozilla.org/editfields.cgi?action=edit&name=$name to finish setting up this field.\n";
### EXTREMELY MOZILLA-SPECIFIC CODE FOLLOWS ###
print "Note to sysadmin:\n";
print "Please run the following on tm-bugs01-master01:\n";
foreach my $host ("10.2.70.20_") {
  print "GRANT SELECT ON `bugs`.`$name` TO 'metrics'\@'$host';\n";
  print "GRANT SELECT ($name) ON `bugs`.`bugs` TO 'metrics'\@'$host';\n";
}

