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

package Bugzilla::Extension::REST::Util;

use strict;
use warnings;

use Bugzilla::Util qw(correct_urlbase);

use Scalar::Util qw(blessed reftype);

use base qw(Exporter);
our @EXPORT = qw(
    inherit_package
    fix_include_exclude
    adjust_fields
    remove_immutables
    ref_urlbase
    stringify_json_objects
);

# Return an URL base appropriate for constructing a ref link 
# normally required by REST API calls.
sub ref_urlbase {
    return correct_urlbase() . "rest";
}

# Add the capabilities of the class
# to the current instance
sub inherit_package {
    my ($self, $pkg) = @_;
    my $new_class = ref($self) . '::' . $pkg;
    my $isa_string = 'our @ISA = qw(' . ref($self) . " $pkg)";
    eval "package $new_class;$isa_string;";
    bless $self, $new_class;
    return $self;
}

sub fix_include_exclude {
    my ($params) = @_;

    # _all is same as default columns
    if ($params->{'include_fields'}
        && ($params->{'include_fields'} eq '_all'
            || $params->{'include_fields'} eq '_default'))
    {
        delete $params->{'include_fields'};
        delete $params->{'exclude_fields'} if $params->{'exclude_fields'};
    }

    if ($params->{'include_fields'} && !ref $params->{'include_fields'}) {
        $params->{'include_fields'} = [ split(/[\s+,]/, $params->{'include_fields'}) ];
    }   
    if ($params->{'exclude_fields'} && !ref $params->{'exclude_fields'}) {
        $params->{'exclude_fields'} = [ split(/[\s+,]/, $params->{'exclude_fields'}) ];
    }
     
    return $params;
}

sub remove_immutables {
    my ($bug) = @_;
    
    # Stuff you can't change, or change directly
    my @immutable = ('reporter', 'creation_time', 'id', 
                     'ref', 'is_everconfirmed', 'remaining_time', 
                     'actual_time', 'percentage_complete');
    foreach my $field (@immutable) {
        delete $bug->{$field};
    }
}

sub adjust_fields {
    my ($params, $result, $differences) = @_;
    
    # $result can be undef (e.g. if there was an error)
    return if !$result;
    
    $params = fix_include_exclude($params);

    if (!$params->{'include_fields'} && $differences) {
        $params->{'exclude_fields'} ||= {};
        push(@{$params->{'exclude_fields'}}, @$differences);
    }

    # Remove everything that's not an include_field
    if ($params->{include_fields}) {
        foreach my $key (keys %$result) {
            if (!grep($_ eq $key, @{$params->{include_fields}})) {
                delete $result->{$key};
            }
        }
    }
      
    # Remove exclude fields
    if ($params->{exclude_fields}) {
        foreach my $exclude (@{$params->{exclude_fields}}) {
            delete $result->{$exclude};
        }
    }   

    return $result;
}


# stringify all objects in data hash:
sub stringify_json_objects {
    for my $val (@_) {
        next unless my $ref = reftype $val;
        if (blessed $val && $val->isa('JSON::XS::Boolean')) {
            $val = $val eq "true" ? 1 : 0;
        }
        elsif ($ref eq 'ARRAY') {
            stringify_json_objects(@$val)
        }
        elsif ($ref eq 'HASH') {
            stringify_json_objects(values %$val)
        }
    }
}

1;
