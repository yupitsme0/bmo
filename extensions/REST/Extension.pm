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
# The Original Code is the REST Bugzilla Extension.
#
# The Initial Developer of the Original Code is Mozilla.
# Portions created by Mozilla are Copyright (C) 2011 Mozilla Corporation.
# All Rights Reserved.
#
# Contributor(s):
#   Dave Lawrence <dkl@mozilla.com>

package Bugzilla::Extension::REST;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Install::Filesystem;

use Bugzilla::Extension::REST::Server;

our $VERSION = '0.01';

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{page_id};

    if ($page =~ /^rest\.api/) {
        # Remove the id param before servicing the request
        my $params = Bugzilla->input_params;
        delete $params->{'id'};
        Bugzilla->input_params($params);

        Bugzilla->usage_mode(USAGE_MODE_JSON);
        local @INC = (bz_locations()->{extensionsdir}, @INC);
        my $server = Bugzilla::Extension::REST::Server->new;
        $server->version('1.1');
        $server->handle();
        exit;
    }
}

sub install_filesystem {
    my ($self,  $args) = @_;
    my $files = $args->{'files'};

    my $extensionsdir = bz_locations()->{'extensionsdir'};
    my $scriptname = $extensionsdir . "/" . __PACKAGE__->NAME . "/bin/rest.cgi";
 
    $files->{$scriptname} = {
        perms => Bugzilla::Install::Filesystem::WS_EXECUTE
    };

    # Add rewrite rule to root .htaccess file if not already included
    my $htaccess = new IO::File(".htaccess", 'r') || die ".htaccess: $!";
    my $htaccess_data;
    { local $/; $htaccess_data = <$htaccess>; }
    $htaccess->close;
    if ($htaccess_data !~ /RewriteRule rest\//) {
        print "Repairing .htaccess...\n";
        if ($htaccess_data !~ /RewriteEngine On/) {
            $htaccess_data .= "\nRewriteEngine On"; 
        }
        $htaccess_data .= "\nRewriteRule rest/(.*)\$ $scriptname/\$1 [NE]";
        $htaccess = new IO::File(".htaccess", 'w') || die $!;
        print $htaccess $htaccess_data;
        $htaccess->close;
    }
}

__PACKAGE__->NAME;
