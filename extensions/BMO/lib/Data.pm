package Bugzilla::Extension::BMO::Data;
use strict;

use base qw(Exporter);
use Tie::IxHash;

our @EXPORT_OK = qw($cf_visible_in_products
                    %group_to_cc_map
                    $blocking_trusted_setters
                    $blocking_trusted_requesters
                    $status_trusted_wanters
                    %always_fileable_group);

# Which custom fields are visible in which products and components. "[]" means
# all components.
#
# IxHash keeps them in insertion order, and so we get regexp priorities right.
# A custom field is visible in a product if it's _not_ listed here, or if it
# is listed here but the product (and component if necessary) is part of its
# hash. 
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
#
# Note no default here - if a custom field isn't listed, anyone can do this
my $blocking_trusted_requesters = {
    qr/^cf_blocking_thunderbird/  => 'thunderbird-trusted-requesters',
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

