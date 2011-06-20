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
# The Original Code is the Roadmap Bugzilla Extension.
#
# The Initial Developer of the Original Code is Mozilla Foundation
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Dave Lawrence <dkl@mozilla.com>

use strict;

package Bugzilla::Extension::Roadmap::Roadmap::Milestone;

use base qw(Bugzilla::Object);

use Bugzilla::CGI;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util qw(trim detaint_signed);

use Bugzilla::Extension::Roadmap::Util;

###############################
####    Initialization     ####
###############################

use constant DB_COLUMNS => qw(
    id
    roadmap_id
    name 
    query 
    sortkey
);

use constant UPDATE_COLUMNS => qw(
    name
    query
    sortkey
);

use constant DB_TABLE => 'roadmap_milestones';
use constant ID_FIELD => 'id';
use constant LIST_ORDER => 'sortkey, name';

use constant VALIDATORS => {
    name    => \&_check_name,
    query   => \&_check_query, 
    sortkey => \&_check_sortkey,
};

#########################
# Database Manipulation #
#########################

sub new {
    my $class = shift;
    my $milestone = $class->SUPER::new(@_);
    return $milestone;
}

sub create {
    my $class = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    $class->check_required_create_fields(@_);
    my $params = $class->run_create_validators(@_);
    my $milestone = $class->insert_create_data($params);

    $dbh->bz_commit_transaction();
    return $milestone;
}

sub update {
    my $self = shift;
    my $changes = $self->SUPER::update(@_);
    return $changes;
}

sub remove_from_db {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();
    $dbh->do('DELETE FROM roadmap_milestones WHERE id = ?',
             undef, $self->id);
    $dbh->bz_commit_transaction();
}

##############
# Validators #
##############

sub _check_name {
    my ($invocant, $name, undef, $params) = @_;
    $name = trim($name);
    my $roadmap_id = $params->{'roadmap_id'};
    $name || ThrowUserError('roadmap_milestone_need_name');
    my $milestone
	    = Bugzilla::Extension::Roadmap::Roadmap::Milestone->new({ name => $name, 
                                                                  roadmap_id => $roadmap_id });
    if ($milestone && (!ref $invocant || $milestone->id != $invocant->id)) {
        ThrowUserError('roadmap_milestone_already_exists', { name => $milestone->name });
    }
    return $name;
}

sub _check_query {
    my ($invocant, $query) = @_;

    $query = trim($query);
    $query || ThrowUserError('roadmap_milestone_query_needed');

    # Create CGI object,  clean it,  and then makes sure it is not empty.
    my $cgi = Bugzilla::CGI->new($query);
    $cgi = clean_search_url($cgi);
    $query = $cgi->canonicalise_query("id");
    $query || ThrowUserError('roadmap_milestone_query_needed');

    return $query;
}

sub _check_sortkey {
    my ($invocant, $sortkey) = @_;

    # Keep a copy in case detaint_signed() clears the sortkey
    my $stored_sortkey = $sortkey;
    
    if (!detaint_signed($sortkey) || $sortkey < MIN_SMALLINT || $sortkey > MAX_SMALLINT) {
        ThrowUserError('roadmap_milestone_sortkey_invalid', {sortkey => $stored_sortkey});
    }
    return $sortkey;
}

#############
# Accessors #
#############

sub id         { return $_[0]->{'id'};         }
sub roadmap_id { return $_[0]->{'roadmap_id'}; }
sub name       { return $_[0]->{'name'};       }
sub query      { return $_[0]->{'query'};      }
sub sortkey    { return $_[0]->{'sortkey'};    }


############
# Mutators #
############

sub set_name    { $_[0]->set('name', $_[1]);    }
sub set_query   { $_[0]->set('query', $_[1]);   }
sub set_sortkey { $_[0]->set('sortkey', $_[1]); }

###################
# Class Accessors #
###################

sub stats {
    my ($self, $refresh) = @_;

    return $self->{'stats'} if exists $self->{'stats'} && !$refresh;
   
    my $dbh = Bugzilla->dbh;
   
    my $search = Bugzilla::Search->new(
	    fields   => ['bug_id'],
        params   => Bugzilla::CGI->new($self->query), 
        no_perms => 1
    );
    my $total_bugs  = $dbh->selectall_arrayref($search->getSQL());
    my $total_count = scalar @$total_bugs;

    $search = Bugzilla::Search->new(
	    fields   => ['bug_id'],
        params   => Bugzilla::CGI->new($self->query . "&bug_status=__open__"), 
        no_perms => 1
    );
    my $open_bugs  = $dbh->selectall_arrayref($search->getSQL());
    my $open_count = scalar @$open_bugs;

    $search = Bugzilla::Search->new(
	    fields   => ['bug_id'],
        params   => Bugzilla::CGI->new($self->query . "&bug_status=__closed__"),
        no_perms => 1
    );
    my $closed_bugs  = $dbh->selectall_arrayref($search->getSQL());
    my $closed_count = scalar @$closed_bugs;

    $self->{'stats'} = {
        open        => $open_count, 
        closed      => $closed_count, 
        total       => $total_count, 
        open_bugs   => $open_bugs, 
        closed_bugs => $closed_bugs, 
        total_bugs  => $total_bugs
    };

    return $self->{'stats'};
}

1;
