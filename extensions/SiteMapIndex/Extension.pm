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

package Bugzilla::Extension::SiteIndex;
use strict;
use base qw(Bugzilla::Extension);

our $VERSION = '1.0';

use Bugzilla::Extension::SiteIndex::Constants;
use Bugzilla::Extension::SiteIndex::Util;
use Bugzilla::Constants qw(bz_locations);
use Bugzilla::Util qw(correct_urlbase get_text);

use DateTime;
use IO::File;

#########
# Pages #
#########

sub template_before_process {
    my ($self, $args) = @_;
    my ($vars, $file) = @$args{qw(vars file)};

    return if !$file eq 'global/header.html.tmpl';
    return unless (exists $vars->{bug} or exists $vars->{bugs});
    my $bugs = exists $vars->{bugs} ? $vars->{bugs} : [$vars->{bug}];
    return if !ref $bugs eq 'ARRAY';

    foreach my $bug (@$bugs) {
        if (!bug_is_ok_to_index($bug)) {
            $vars->{sitemap_noindex} = 1;
            last;
        }
    }
}

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{page_id};

    if ($page =~ m{^sitemap/sitemap\.}) {
        _page_sitemap();
    }
}

sub _page_sitemap {
    my $map = generate_sitemap();
    print Bugzilla->cgi->header('text/xml');
    print $map;
    exit;
}

################
# Installation #
################

sub install_before_final_checks {
    my ($self) = @_;
    if (!correct_urlbase()) {
        print STDERR get_text('sitemap_no_urlbase'), "\n";
        return;
    }
    if (Bugzilla->params->{'requirelogin'}) {
        print STDERR get_text('sitemap_requirelogin'), "\n";
        return;
    }
    $self->_fix_robots_txt();
}

sub _fix_robots_txt {
    my ($self) = @_;
    my $cgi_path = bz_locations()->{'cgi_path'};
    my $robots_file = "$cgi_path/robots.txt";
    my $current_fh = new IO::File("$cgi_path/robots.txt", 'r');
    if (!$current_fh) {
        warn "$robots_file: $!";
        return;
    }

    my $current_contents;
    { local $/; $current_contents = <$current_fh> }
    $current_fh->close();

    return if $current_contents =~ m{^Allow: \/\*show_bug\.cgi}ms;
    my $backup_name = "$cgi_path/robots.txt.old";
    print get_text('sitemap_fixing_robots', { current => $robots_file,
                                              backup  => $backup_name }), "\n";
    rename $robots_file, $backup_name or die "backup failed: $!";

    my $new_fh = new IO::File($self->package_dir . '/robots.txt', 'r');
    $new_fh || die "Could not open new robots.txt template file: $!";
    my $new_contents;
    { local $/; $new_contents = <$new_fh> }
    $new_fh->close() || die "Could not close new robots.txt template file: $!";

    my $sitemap_url = correct_urlbase() . SITEMAP_URL;
    $new_contents =~ s/SITEMAP_URL/$sitemap_url/;
    $new_fh = new IO::File("$cgi_path/robots.txt", 'w');
    $new_fh || die "Could not open new robots.txt file: $!";
    print $new_fh $new_contents;
    $new_fh->close() || die "Could not close new robots.txt file: $!";
}

__PACKAGE__->NAME;
