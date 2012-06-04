#!/usr/bin/perl -wT
use strict;
use lib qw(. lib);
use Bugzilla;
use Bugzilla::Error;
my $cgi = Bugzilla->cgi;
if ($ENV{QUERY_STRING}) {
    print "Content-type: text/plain\n\ncheese?\n";
} else {
    print $cgi->header(-refresh=> '10; URL=query.cgi');
    ThrowUserError("buglist_parameters_required");
}
