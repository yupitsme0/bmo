#!/usr/bin/perl -wT

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Error;

my $cgi = Bugzilla->cgi;
print $cgi->header(-refresh=> '10; URL=query.cgi');
ThrowUserError("buglist_parameters_required");
