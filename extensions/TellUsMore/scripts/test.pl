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
# The Original Code is the Bugzilla TellUsMore Extension.
#
# The Initial Developer of the Original Code is the Mozilla Foundation.
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Byron Jones <glob@mozilla.com>

#!/usr/bin/perl -w

use strict;

BEGIN {
    use File::Basename;
    my $root = dirname(__FILE__);
    push @INC, "$root/../../../";
}

use HTTP::Cookies;
use XMLRPC::Lite;
use Data::Dumper;
use File::Slurp;
use MIME::Base64;

use Bugzilla;

my $proxy = XMLRPC::Lite->proxy(
    Bugzilla->params->{'urlbase'} . 'xmlrpc.cgi',
    cookie_jar => HTTP::Cookies->new(
        'file' => dirname(__FILE__) . '/cookies.txt',
        'autosave' => 1
    )
);
my $result;

$result = $proxy->call(
    'User.login',
    {
        login => 'tellusmore@input.bugs',
        password => 'one2three',
        remember => 1,
    }
);
_die_on_fault($result);

$result = $proxy->call(
    'TellUsMore.submit',
    {
        creator => 'byron@glob.com.au',
        product => 'Firefox',
        summary => 'YouTube is broken',
        user_agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:7.0a2) Gecko/20110811 Firefox/7.0a2',
        restricted => 0,
        description => 'youtube does not work.  fix it.',
        version => '4.0 Branch',
        attachments => [
            {
                filename => 'mason.jpg',
                content_type => 'image/jpeg',
                content => encode_base64(
                    read_file(dirname(__FILE__) . '/mason.jpg', binmode => ':raw')
                ),
            },
            {
                filename => 'test.pl',
                content_type => 'text/plain',
                content => encode_base64(
                    read_file(dirname(__FILE__) . '/test.pl', binmode => ':raw')
                ),
            },
        ],
    }
);
_die_on_fault($result);

my $id = $result->result();
print "id $id\n";

#

sub _die_on_fault {
    my $soapresult = shift;
    if ($soapresult->fault) {
        my ($package, $filename, $line) = caller;
        die '[' . $soapresult->faultcode . '] ' . $soapresult->faultstring . "\n";
    }
}

