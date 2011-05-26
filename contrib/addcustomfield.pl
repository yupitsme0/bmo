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

Bugzilla->usage_mode(USAGE_MODE_CMDLINE);

my $name = shift
    or die "Please provide a field name.\n";

Bugzilla::Field->create({
    name        => $name,
    description => 'Please give me a description!',
    type        => FIELD_TYPE_SINGLE_SELECT,
    mailhead    => 0,
    enter_bug   => 1,
    obsolete    => 1,
    custom      => 1,
    buglist     => 0,
});
print "Done!\n";

my $urlbase = Bugzilla->params->{urlbase};
print "Please visit ${urlbase}editfields.cgi?action=edit&name=$name to finish setting up this field.\n";
