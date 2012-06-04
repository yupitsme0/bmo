#!/usr/bin/perl
use strict;
use lib qw(. lib);
if ($ENV{QUERY_STRING} eq 'bug') {
    use Bugzilla;
    use Bugzilla::Error;
    my $cgi = Bugzilla->cgi;
    print $cgi->header(-refresh=> '10; URL=query.cgi');
    ThrowUserError("buglist_parameters_required");
} elsif ($ENV{QUERY_STRING} eq 'cgi') {
    use CGI;
    my $cgi = CGI->new;
    print $cgi->header(-refresh=> '10; URL=query.cgi');
    ThrowUserError("buglist_parameters_required");
} else {
    print "Content-type: text/plain\n\nfallthrough?\n";
}
