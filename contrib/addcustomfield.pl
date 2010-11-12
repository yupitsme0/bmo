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
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Token;

die "Please provide a field name.\n" if !defined $::ARGV[0];

my $name = $::ARGV[0];
my $type = FIELD_TYPE_MULTI_SELECT;

$vars->{'field'} = Bugzilla::Field->create({
    name        => $name,
    description => 'Please give me a description!',
    type        => $type,
    sortkey     => 0,
    mailhead    => 0,
    enter_bug   => 1,
    obsolete    => 1,
    custom      => 1,
    buglist     => ($type == FIELD_TYPE_MULTI_SELECT) ? 0 : 1,
    visibility_field_id => '',
    visibility_value_id => '',
    value_field_id => '',
});

print "Done!\n";
print "Please visit https://bugzilla.mozilla.org/editfields.cgi?action=edit&name=$name to finish setting up this field.\n";

