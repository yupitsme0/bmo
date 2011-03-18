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
# The Original Code is the Sitemap Bugzilla Extension.
#
# The Initial Developer of the Original Code is Everything Solved, Inc.
# Portions created by the Initial Developer are Copyright (C) 2010 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Max Kanat-Alexander <mkanat@bugzilla.org>
#   Dave Lawrence <dkl@mozilla.com>

package Bugzilla::Extension::SiteIndex::Util;
use strict;
use base qw(Exporter);
our @EXPORT = qw(
    generate_sitemap 
    bug_is_ok_to_index
);

use Bugzilla::Extension::SiteIndex::Constants;

use Bugzilla::Util qw(correct_urlbase datetime_from url_quote);
use Bugzilla::Constants qw(bz_locations);

use Scalar::Util qw(blessed);
use IO::Compress::Gzip qw(gzip $GzipError);

sub too_young_date {
    my $hours_ago = DateTime->now(time_zone => Bugzilla->local_timezone);
    $hours_ago->subtract(hours => SITEMAP_DELAY);
    return $hours_ago;
}

sub bug_is_ok_to_index {
    my ($bug) = @_;
    return 1 unless blessed($bug) && $bug->isa('Bugzilla::Bug');
    my $creation_ts = datetime_from($bug->creation_ts);
    return ($creation_ts lt too_young_date()) ? 1 : 0;
}

# We put two things in the Sitemap: a list of Browse links for products,
# and links to bugs.
sub generate_sitemap {
    # If file is less than SITEMAP_AGE hours old, then read in and send to caller.
    # If greater, then regenerate and send the new version.
    my  $index_path = bz_locations()->{'datadir'} . "/sitemap_index.xml";
    if (-e $index_path) {
        my $index_mtime = (stat($index_path))[9];
        my $index_hours = sprintf("%d", (time() - $index_mtime) / 60 / 60); # in hours
        if ($index_hours < SITEMAP_AGE) {
            my $index_fh = new IO::File($index_path, 'r');
            $index_fh || die "Could not open current sitemap index: $!";
            my $index_contents;
            { local $/; $index_contents = <$index_fh> }
            $index_fh->close() || die "Could not close current sitemap index: $!";

            return $index_contents;
        }
    }

    # Set the atime and mtime of the index file to the current time
    # in case another request is made before we finish.
    utime(undef, undef, $index_path);

    # Sitemaps must never contain private data.
    Bugzilla->logout_request();
    my $user = Bugzilla->user;
    my $products = $user->get_accessible_products;

    my $num_bugs = SITEMAP_MAX - scalar(@$products);
    # We do this date math outside of the database because databases
    # usually do better with a straight comparison value.
    my $hours_ago = too_young_date();

    # We don't use Bugzilla::Bug objects, because this could be a tremendous
    # amount of data, and we only want a little. Also, we only display
    # bugs that are not in any group. We show the last $num_bugs
    # most-recently-updated bugs.
    my $dbh = Bugzilla->dbh;
    my $bug_sth = $dbh->prepare(
        'SELECT bugs.bug_id, bugs.delta_ts
           FROM bugs
                LEFT JOIN bug_group_map ON bugs.bug_id = bug_group_map.bug_id
          WHERE bug_group_map.bug_id IS NULL AND creation_ts < ? 
        ' . $dbh->sql_limit($num_bugs, '?'));

    my $filecount = 1;
    my $filelist = [];
    my $offset = 0;

    while (1) {
        my $bugs = [];

        $bug_sth->execute($hours_ago, $offset);

        while (my ($bug_id, $delta_ts) = $bug_sth->fetchrow_array()) {
            push(@$bugs, { bug_id => $bug_id, delta_ts => $delta_ts });
        }

        last if !@$bugs;

	    # We only need the product links in the first sitemap file
	    $products = [] if $filecount > 1;

        push(@$filelist, _generate_sitemap_file($filecount, $products, $bugs));

        $filecount++;
        $offset += $num_bugs; 
    }

    # Generate index file
    return _generate_sitemap_index($filelist);
}

sub _generate_sitemap_index {
    my ($filelist) = @_;
    
    my $dbh = Bugzilla->dbh;
    my $timestamp = $dbh->selectrow_array(
        "SELECT " . $dbh->sql_date_format('NOW()', '%Y-%m-%d'));

    my $index = <<END;
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
END

    foreach my $filename (@$filelist) {
        $index .= "
  <sitemap>
    <loc>" . correct_urlbase() . "$filename</loc>
    <lastmod>$timestamp</lastmod>
  </sitemap>
";
    }

    $index .= <<END;
</sitemapindex>
END

    my  $index_path = bz_locations()->{'datadir'} . "/sitemap_index.xml";
    my $new_index_fh = new IO::File($index_path, 'w');
    $new_index_fh || die "Could not open new sitemap index: $!";
    print $new_index_fh $index;
    $new_index_fh->close() || die "Could not close new sitemap index: $!";

    return $index;
}

sub _generate_sitemap_file {
    my ($filecount, $products, $bugs) = @_;

    my $bug_url = correct_urlbase() . 'show_bug.cgi?id=';
    my $product_url = correct_urlbase() . 'describecomponents.cgi?product=';

    my $sitemap = <<END;
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
END

    foreach my $product (@$products) {
        $sitemap .= "
  <url>
    <loc>" . $product_url . url_quote($product->name) . "</loc>
    <changefreq>daily</changefreq>
    <priority>0.4</priority>
  </url>
";   
    }

    foreach my $bug (@$bugs) {
        $sitemap .= "
  <url>
    <loc>" . $bug_url . $bug->{bug_id} . "</loc>
    <lastmod>" . datetime_from($bug->{delta_ts}, 'UTC')->iso8601 . 'Z' . "</lastmod>
  </url> 
";
    }

    $sitemap .= <<END;
</urlset>
END

    # Write the compressed sitemap data to a file in the cgi root so that they can
    # be accessed by the search engines.
    gzip \$sitemap => bz_locations()->{'cgi_path'} . "/sitemap$filecount.xml.gz" 
        || die "gzip failed: $GzipError\n"; 

    return "sitemap$filecount.xml.gz";
}

1;
