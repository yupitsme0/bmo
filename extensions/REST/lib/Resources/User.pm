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

package Bugzilla::Extension::REST::Resources::User;

use strict;

use base qw(Exporter Bugzilla::WebService);

use Bugzilla::WebService::User;
use Bugzilla::WebService::Util qw(filter filter_wants);

use Bugzilla::Extension::REST::Util qw(inherit_package fix_include_exclude 
                                       adjust_fields ref_urlbase);
use Bugzilla::Extension::REST::Constants;

use Tie::IxHash;
use Data::Dumper;

#############
# Resources #
#############

# IxHash keeps them in insertion order, and so we get regexp priorities right.
our $_resources = {};
tie(%$_resources, "Tie::IxHash",
    qr{/user$} => {
        GET => 'user_GET'
    }, 
    qr{/user/([^/]+)$} => {
        GET => 'one_user_GET'
    }
);

sub resources { return $_resources };

###########
# Methods #
###########

sub user_GET {
    my ($self, $params) = @_;

    my $include_disabled = exists $params->{include_disabled} 
                           ? $params->{include_disabled} 
                           : 0;
    my $match_value = ref $params->{match} 
                      ? $params->{match}
                      : [ $params->{match} ];

    $self = inherit_package($self, 'Bugzilla::WebService::User');
    my $result = $self->get({ match => $match_value, 
                              include_disabled => $include_disabled });

    my @adjusted_users = map { $self->_fix_user($params, $_) }
                         @{ $result->{users} };
    
    $self->_bz_response_code(STATUS_OK);
    return { users => \@adjusted_users };
}

sub one_user_GET {
    my ($self, $params) = @_;

    my $nameid = $self->_bz_regex_matches->[0];
    
    my $param = "names";
    if ($nameid =~ /^\d+$/) {
        $param = "ids";
    }
    
    $self = inherit_package($self, 'Bugzilla::WebService::User');
    my $result = $self->get({ $param => $nameid });

    my $adjusted_user = $self->_fix_user($params, $result->{'users'}[0]);

    $self->_bz_response_code(STATUS_OK);
    return $adjusted_user;
}

##################
# Helper Methods #
##################

sub _fix_user {
    my ($self, $params, $user) = @_;

    $user = adjust_fields($params, $user);

    $user->{ref} = ref_urlbase() . "/user/" . $user->{id};

    return $user;
}

1;
