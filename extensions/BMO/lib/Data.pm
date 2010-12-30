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
# The Original Code is the BMO Bugzilla Extension.
#
# The Initial Developer of the Original Code is Gervase Markham.
# Portions created by the Initial Developer are Copyright (C) 2010 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Gervase Markham <gerv@gerv.net>

package Bugzilla::Extension::BMO::Data;
use strict;

use base qw(Exporter);
use Tie::IxHash;

our @EXPORT_OK = qw($cf_visible_in_products
                    %group_to_cc_map
                    $blocking_trusted_setters
                    $blocking_trusted_requesters
                    $status_trusted_wanters
                    %always_fileable_group
                    %product_sec_bits);

# Which custom fields are visible in which products and components.
#
# By default, custom fields are visible in all products. However, if the name
# of the field matches any of these regexps, it is only visible if the 
# product (and component if necessary) is a member of the attached hash. []
# for component means "all".
#
# IxHash keeps them in insertion order, and so we get regexp priorities right.
my $cf_visible_in_products;
tie(%$cf_visible_in_products, "Tie::IxHash", 
    qr/^cf_blocking_fennec/ => {
        "addons.mozilla.org"  => [],
        "AUS"                 => [],
        "Core"                => [],
        "Fennec"              => [],
        "mozilla.org"         => ["Release Engineering"],
        "Mozilla Services"    => [],
        "NSPR"                => [],
        "support.mozilla.com" => [],
        "Toolkit"             => [],
    },
    qr/^cf_blocking_thunderbird|cf_status_thunderbird/ => {
        "support.mozillamessaging.com"  => [],
        "Thunderbird"                   => [],
        "MailNews Core"                 => [],
        "Mozilla Messaging"             => [],
        "Websites"                      => ["www.mozillamessaging.com"],
    },
    qr/^cf_blocking_seamonkey|cf_status_seamonkey/ => {
      "Composer"              => [],
      "MailNews Core"         => [],
      "Mozilla Localizations" => [],
      "Other Applications"    => [],
      "SeaMonkey"             => [],
    },
   qr/^cf_blocking_|cf_status/ => {
      "addons.mozilla.org"    => [],
      "AUS"                   => [],
      "Camino"                => [],
      "Core Graveyard"        => [],
      "Core"                  => [],
      "Directory"             => [],
      "Fennec"                => [],
      "Firefox"               => [],
      "MailNews Core"         => [],
      "mozilla.org"           => ["Release Engineering"],
      "Mozilla Localizations" => [],
      "Mozilla Services"      => [],
      "NSPR"                  => [],
      "NSS"                   => [],
      "Other Applications"    => [],
      "SeaMonkey"             => [],
      "support.mozilla.com"   => [],
      "Tech Evangelism"       => [],
      "Testing"               => [],
      "Toolkit"               => [],
      "Websites"              => ["getpersonas.com"],
    }      
);

# Who to CC when certain groups are added or removed.
my %group_to_cc_map = (
  qr/bugzilla-security/         => 'security@bugzilla.org',
  qr/websites-security/         => 'website-drivers@mozilla.org',
  qr/webtools-security/         => 'webtools-security@mozilla.org',
  qr/client-services-security/  => 'amo-admins@mozilla.org',
  qr/tamarin-security/          => 'tamarinsecurity@adobe.com',
  qr/core-security/             => 'security@mozilla.org'
);

# Only users in certain groups can change certain custom fields in 
# certain ways. 
#
# Who can set "cf_blocking_*" to +?
my $blocking_trusted_setters = {
    'cf_blocking_fennec'          => 'fennec-drivers',
    'cf_blocking_20'              => 'mozilla-next-drivers',
    qr/^cf_blocking_thunderbird/  => 'thunderbird-drivers',
    qr/^cf_blocking_seamonkey/    => 'seamonkey-council',
    '_default'                    => 'mozilla-stable-branch-drivers',
  };

# Who can request "cf_blocking_*"?
my $blocking_trusted_requesters = {
    qr/^cf_blocking_thunderbird/  => 'thunderbird-trusted-requesters',
    '_default'                    => 'canconfirm', # Bug 471582
};

# Who can set "cf_status_*" to "wanted"?
my $status_trusted_wanters = {
    'cf_status_20'                => 'mozilla-next-drivers',
    qr/^cf_status_thunderbird/    => 'thunderbird-drivers',
    qr/^cf_status_seamonkey/      => 'seamonkey-council',
    '_default'                    => 'mozilla-stable-branch-drivers',
};

# Groups in which you can always file a bug, whoever you are.
my %always_fileable_group = (
    'bugzilla-security'                 => 1,
    'client-services-security'          => 1,
    'consulting'                        => 1,
    'core-security'                     => 1,
    'infra'                             => 1,
    'marketing-private'                 => 1,
    'mozilla-confidential'              => 1,
    'mozilla-corporation-confidential'  => 1,
    'mozilla-messaging-confidential'    => 1,
    'tamarin-security'                  => 1,
    'websites-security'                 => 1,
    'webtools-security'                 => 1,
);

# Mapping of products to their security bits
my %product_sec_bits = (
    "mozilla.org"                  =>  6, # mozilla-confidential
    "Webtools"                     => 12, # webtools-security
    "Marketing"                    => 14, # marketing-private
    "addons.mozilla.org"           => 23, # client-services-security
    "AUS"                          => 23,
    "Mozilla Services"             => 23,
    "Mozilla Corporation"          => 26, # mozilla-corporation-confidential
    "Mozilla Metrics"              => 32, # metrics-private
    "Legal"                        => 40, # legal 
    "Mozilla Messaging"            => 45, # mozilla-messaging-confidential 
    "Websites"                     => 52, # websites-security
    "Mozilla Developer Network"    => 52,
    "support.mozilla.com"          => 52,
    "quality.mozilla.org"          => 52,
    "Skywriter"                    => 52,
    "support.mozillamessaging.com" => 52,
    "Bugzilla"                     => 53, # bugzilla-security
    "Testopia"                     => 53,
    "Tamarin"                      => 65, # tamarin-security
    "Mozilla PR"                   => 73, # pr-private
    "_default"                     => 2   # core-security
);

1;
