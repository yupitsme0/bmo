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

package Bugzilla::Extension::REST::View;

use strict;

use Bugzilla::Error;

use constant CONTENT_TYPE_VIEW_MAP => {
    'text/html'        => 'HTML', 
    'application/json' => 'JSON', 
    'text/xml'         => 'XML', 
};

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    
    my $self = {};
    $self->{_content_type} = shift || 'application/json'; 
    
    my $view = CONTENT_TYPE_VIEW_MAP->{$self->{_content_type}};
    $view || ThrowUserError('rest_illegal_content_type_view',
                            { content_type => $self->{_content_type} });
    
    my $module = "Bugzilla::Extension::REST::View::$view";
    eval "require $module";
    if ($@) {
        die "Could not load view $module: $!"; 
    }
    bless $self, $module;
     
    return $self;
}

sub view {
    my ($self, $data) = @_;
    # Implemented by individual view modules
}

1;
