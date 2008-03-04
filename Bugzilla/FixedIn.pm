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
# The Original Code is the Bugzilla Bug Tracking System.
#
# Contributor(s): Tiago R. Mello <timello@async.com.br>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;

package Bugzilla::FixedIn;

use base qw(Bugzilla::Object);

use Bugzilla::Install::Requirements qw(vers_cmp);
use Bugzilla::Util;
use Bugzilla::Error;

################################
#####   Initialization     #####
################################

use constant DEFAULT_VERSION => '';

use constant DB_TABLE => 'cf_fixed_in';

use constant DB_COLUMNS => qw(
    id
    value
    product_id
);

use constant NAME_FIELD => 'value';
# This is "id" because it has to be filled in and id is probably the fastest.
# We do a custom sort in new_from_list below.
use constant LIST_ORDER => 'id';

sub new {
    my $class = shift;
    my $param = shift;
    my $dbh = Bugzilla->dbh;

    my $product;
    if (ref $param) {
        $product = $param->{product};
        my $name = $param->{name};
        if (!defined $product) {
            ThrowCodeError('bad_arg',
                {argument => 'product',
                 function => "${class}::new"});
        }
        if (!defined $name) {
            ThrowCodeError('bad_arg',
                {argument => 'name',
                 function => "${class}::new"});
        }

        my $condition = 'product_id = ? AND value = ?';
        my @values = ($product->id, $name);
        $param = { condition => $condition, values => \@values };
    }

    unshift @_, $param;
    return $class->SUPER::new(@_);
}

sub new_from_list {
    my $self = shift;
    my $list = $self->SUPER::new_from_list(@_);
    return [sort { vers_cmp(lc($a->name), lc($b->name)) } @$list];
}

sub bug_count {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{'bug_count'}) {
        $self->{'bug_count'} = $dbh->selectrow_array(qq{
            SELECT COUNT(*) FROM bug_cf_fixed_in, bugs
            WHERE bugs.bug_id = bug_cf_fixed_in.bug_id
              AND bugs.product_id = ?
              AND value = ?}, undef,
            ($self->product_id, $self->name)) || 0;
    }
    return $self->{'bug_count'};
}

sub remove_from_db {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    # The version cannot be removed if there are bugs
    # associated with it.
    if ($self->bug_count) {
        ThrowUserError("version_has_bugs", { nb => $self->bug_count });
    }

    $dbh->do(q{DELETE FROM cf_fixed_in WHERE product_id = ? AND value = ?},
              undef, ($self->product_id, $self->name));
}

sub update {
    my $self = shift;
    my ($name, $product) = @_;
    my $dbh = Bugzilla->dbh;

    $name || ThrowUserError('version_not_specified');

    # Remove unprintable characters
    $name = clean_text($name);

    return 0 if ($name eq $self->name);
    my $version = new Bugzilla::FixedIn({ product => $product, name => $name });

    if ($version) {
        ThrowUserError('version_already_exists',
                       {'name' => $version->name,
                        'product' => $product->name});
    }

    trick_taint($name);
    $dbh->do("UPDATE bug_cf_fixed_in SET value = ?
              WHERE value = ?
              AND bug_id IN (SELECT bug_id from bugs where product_id = ?)", undef,
              ($name, $self->name, $self->product_id));

    $dbh->do("UPDATE cf_fixed_in SET value = ?
              WHERE product_id = ? AND value = ?", undef,
              ($name, $self->product_id, $self->name));

    $self->{'value'} = $name;

    return 1;
}

###############################
#####     Accessors        ####
###############################

sub name       { return $_[0]->{'value'};      }
sub product_id { return $_[0]->{'product_id'}; }

###############################
#####     Subroutines       ###
###############################

sub check_version {
    my ($product, $version_name) = @_;

    $version_name || ThrowUserError('version_not_specified');
    my $version = new Bugzilla::FixedIn(
        { product => $product, name => $version_name });
    unless ($version) {
        ThrowUserError('version_not_valid',
                       {'product' => $product->name,
                        'version' => $version_name});
    }
    return $version;
}

sub create {
    my ($name, $product) = @_;
    my $dbh = Bugzilla->dbh;

    # Cleanups and validity checks
    $name || ThrowUserError('version_blank_name');

    # Remove unprintable characters
    $name = clean_text($name);

    my $version = new Bugzilla::FixedIn({ product => $product, name => $name });
    if ($version) {
        ThrowUserError('version_already_exists',
                       {'name' => $version->name,
                        'product' => $product->name});
    }

    # Add the new version
    trick_taint($name);
    $dbh->do(q{INSERT INTO cf_fixed_in (value, product_id)
               VALUES (?, ?)}, undef, ($name, $product->id));

    return new Bugzilla::FixedIn($dbh->bz_last_key('cf_fixed_in', 'id'));
}

1;

