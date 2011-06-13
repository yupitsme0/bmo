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

package Bugzilla::Extension::Roadmap::Roadmap;

use base qw(Bugzilla::Object);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util qw(trim detaint_signed validate_date);

use Bugzilla::Extension::Roadmap::Roadmap::Milestone;
use Bugzilla::Extension::Roadmap::Util;

###############################
####    Initialization     ####
###############################

# This is a sub because it needs to call other subroutines.
sub  DB_COLUMNS {
    my $dbh = Bugzilla->dbh;
    my @columns = (qw(
        id
        name
        description
        owner
        sortkey
        isactive),
        $dbh->sql_date_format('deadline', '%Y-%m-%d') . ' AS deadline',
    );
    return @columns;
}

use constant UPDATE_COLUMNS => qw(
    name
    description
    owner
    sortkey
    isactive
    deadline
);

use constant DB_TABLE => 'roadmap';
use constant ID_FIELD => 'id';
use constant LIST_ORDER => 'sortkey, name';

use constant VALIDATORS => {
    name        => \&_check_name,
    description => \&_check_description,
    owner       => \&_check_owner,
    sortkey     => \&_check_sortkey,
    isactive    => \&Bugzilla::Object::check_boolean,
    deadline    => \&_check_deadline,
};

#########################
# Database Manipulation #
#########################

sub new {
    my $class = shift;
    my $roadmap = $class->SUPER::new(@_);
    return $roadmap;
}

sub create {
    my $class = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    $class->check_required_create_fields(@_);
    my $params = $class->run_create_validators(@_);
    my $roadmap = $class->insert_create_data($params);

    $dbh->bz_commit_transaction();
    return $roadmap;
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
    $dbh->do('DELETE FROM roadmap_milestones WHERE roadmap_id = ?',
             undef, $self->id);
    $dbh->do('DELETE FROM roadmap WHERE id = ?', 
             undef, $self->id);
    $dbh->bz_commit_transaction();
}

##############
# Validators #
##############

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError('roadmap_need_name');
    my $roadmap 
	    = Bugzilla::Extension::Roadmap::Roadmap->new({ name => $name });
    if ($roadmap && (!ref $invocant || $roadmap->id != $invocant->id)) {
        ThrowUserError('roadmap_already_exists', { name => $roadmap->name });
    }
    return $name;
}

sub _check_description {
    my ($invocant, $description) = @_;
    $description = trim($description);
    $description || ThrowUserError('roadmap_need_description');
    return $description;
}

sub _check_owner {
    my ($invocant, $owner) = @_;
    $owner = trim($owner);
    $owner || ThrowUserError('roadmap_need_owner');
    my $owner_id = Bugzilla::User->check($owner)->id;
    return $owner_id;
}

sub _check_sortkey {
    my ($invocant, $sortkey) = @_;

    # Keep a copy in case detaint_signed() clears the sortkey
    my $stored_sortkey = $sortkey;
    
    if (!detaint_signed($sortkey) || $sortkey < MIN_SMALLINT || $sortkey > MAX_SMALLINT) {
        ThrowUserError('roadmap_sortkey_invalid', {sortkey => $stored_sortkey});
    }
    return $sortkey;
}

sub _check_deadline {
    my ($invocant, $date) = @_;
    $date = trim($date);
    return undef if !$date;
    validate_date($date)
        || ThrowUserError('illegal_date', { date   => $date,
                                            format => 'YYYY-MM-DD' });
    return $date;
}

#############
# Accessors #
#############

sub id          { return $_[0]->{'id'};          }
sub name        { return $_[0]->{'name'};        }
sub description { return $_[0]->{'description'}; }
sub is_active   { return $_[0]->{'isactive'};    }
sub sortkey     { return $_[0]->{'sortkey'};     }
sub deadline    { return $_[0]->{'deadline'};    }

sub owner { 
    return Bugzilla::User->new($_[0]->{'owner'}); 
}

############
# Mutators #
############

sub set_name        { $_[0]->set('name', $_[1]);        }
sub set_description { $_[0]->set('description', $_[1]); }
sub set_is_active   { $_[0]->set('isactive', $_[1]);    } 
sub set_owner       { $_[0]->set('owner', $_[1]);       }
sub set_sortkey     { $_[0]->set('sortkey', $_[1]);     }
sub set_deadline    { $_[0]->set('deadline', $_[1]);    }

###################
# Class Accessors #
###################

sub milestones { 
    my ($self, $with_stats) = @_;
    
    return $self->{'milestones'} if exists $self->{'milestones'};

    $self->{'milestones'}
        = Bugzilla::Extension::Roadmap::Roadmap::Milestone->match({ roadmap_id => $self->id });
    
    return $self->{'milestones'};
}

sub stats {
    my ($self, $refresh) = @_;

    return $self->{'stats'} if exists $self->{'stats'} && !$refresh;
    
    my %total;
    my %open;
    my %closed;

    # We get the union of each of the bug lists in case some of the milestones
    # contain duplicate bug ids in there queries.
    foreach my $milestone (@{ $self->milestones }) {
        my $results = $milestone->stats;
        foreach my $bug_id (@{ $results->{'total_bugs'} }) {
            $total{$bug_id} = 1;
        }
        foreach my $bug_id (@{ $results->{'open_bugs'} }) {
            $open{$bug_id} = 1;
        }
        foreach my $bug_id (@{ $results->{'closed_bugs'} }) {
            $closed{$bug_id} = 1;
        }
    }
    
    $self->{'stats'} = {
        total       => scalar keys %total, 
        open        => scalar keys %open, 
        closed      => scalar keys %closed,
        total_bugs  => [ keys %total ],
        open_bugs   => [ keys %open ],
        closed_bugs => [ keys %closed ],
    };

    return $self->{'stats'};
}

1;
