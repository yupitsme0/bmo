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

package Bugzilla::Extension::Roadmap;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Token;
use Bugzilla::Group;

use Bugzilla::Extension::Roadmap::Util;
use Bugzilla::Extension::Roadmap::Roadmap;
use Bugzilla::Extension::Roadmap::Roadmap::Milestone;

our $VERSION = '0.01';

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    $args->{'schema'}->{'roadmap'} = {
        FIELDS => [
            id => {
                TYPE       => 'SMALLSERIAL',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
            },
            name => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1,
            },
            description => {
                TYPE    => 'MEDIUMTEXT',
                NOTNULL => 1,
            },
            isactive => {
                TYPE    => 'BOOLEAN', 
                NOTNULL => 1,
                DEFAULT => 'TRUE',
            },
            owner => {
                TYPE       => 'INT3', 
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'profiles',
                    COLUMN => 'userid'
                },
            },
            sortkey => {
                TYPE    => 'INT2', 
                NOTNULL => 1,
                DEFAULT => 0
            },
            deadline => {
                TYPE => 'DATETIME'
            },
        ],
        INDEXES => [
            roadmap_name_idx => {
                FIELDS => ['name'],
                TYPE => 'UNIQUE'
            },
        ],
    };

    $args->{'schema'}->{'roadmap_milestones'} = {
        FIELDS => [
            id => {
                TYPE       => 'SMALLSERIAL',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
            },
            roadmap_id => {
                TYPE       => 'INT2',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'roadmap',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            name => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1,
            },
            sortkey => {
                TYPE    => 'INT2',
                NOTNULL => 1,
                DEFAULT => 0
            },
            query => {
                TYPE    => 'MEDIUMTEXT',
                NOTNULL => 1,
            },
            deadline => {
                TYPE => 'DATETIME'
            }, 
        ],
        INDEXES => [
            roadmap_fields_unique_idx => {
                FIELDS => [qw(roadmap_id name)], 
                TYPE => 'UNIQUE'
            },
        ],
    };
}

sub install_update_db {
    my $group = new Bugzilla::Group({ name => 'editroadmaps' });
    if (!$group) {
        Bugzilla::Group->create({ 
            name        => 'editroadmaps', 
            description => 'Edit Roadmaps', 
            userregexp  => '', 
            isactive    => 1,  
            icon_url    => '', 
            isbuggroup  => 0
        });
    }
}

sub template_before_process {
    my ($self, $args) = @_;
    my ($vars, $file) = @$args{qw(vars file)};

    if ($file =~ /^global\/common-links/) {
        $vars->{'roadmaps'} = scalar @{ Bugzilla::Extension::Roadmap::Roadmap->match({ isactive => 1 }) };
    }
};

sub page_before_template {
    my ($self, $args) = @_;
    my ($vars, $page) = @$args{qw(vars page_id)};

    my $user     = Bugzilla->user;
    my $cgi      = Bugzilla->cgi;
    my $template = Bugzilla->template;
    my $input    = Bugzilla->input_params;

    my $can_edit = $user->in_group('editroadmaps');

    if ($page eq 'roadmap.html') {
        Bugzilla->switch_to_shadow_db;

        if ($input->{'name'}) { 
            $vars->{'roadmap'}
                =  Bugzilla::Extension::Roadmap::Roadmap->new({ name => $input->{'name'} });
        }
        else {
            $vars->{'roadmap_list'}
                = Bugzilla::Extension::Roadmap::Roadmap->match({ isactive => 1 });
        }

        print $cgi->header();
        $template->process("pages/roadmap.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit;
    }

    if ($page eq 'roadmap/list.html') {
	    $can_edit || ThrowUserError("auth_failure", { group  => "editroadmaps",
                                         		      action => "edit",
                                                      object => "roadmaps" });

        my $action = $input->{'action'} || "";
        my $token  = $input->{'token'};

        if ($action eq 'update') {
            check_token_data($token, 'edit_roadmap');

            my $roadmap =
                Bugzilla::Extension::Roadmap::Roadmap->check($input->{'old_name'});

            $roadmap->set_name($input->{'name'});
            $roadmap->set_description($input->{'description'});
            $roadmap->set_owner($input->{'owner'});
            $roadmap->set_sortkey($input->{'sortkey'});
            $roadmap->set_deadline($input->{'deadline'});
            $roadmap->set_is_active($input->{'is_active'});
            my $changes = $roadmap->update();

            $vars->{'message'} = 'roadmap_updated';
            $vars->{'roadmap'} = $roadmap;
            $vars->{'changes'} = $changes;
            delete_token($token);
        }

        if ($action eq 'new') {
            check_token_data($token, 'create_roadmap');
  	    
	        # Do the user matching
  	        Bugzilla::User::match_field ({ 'owner' => { 'type' => 'single' }});
  	    
            my $roadmap = Bugzilla::Extension::Roadmap::Roadmap->create({
                name        => $input->{'name'},
                description => $input->{'description'},
                owner       => $input->{'owner'},
            });
    
            $vars->{'message'} = 'roadmap_created';
            $vars->{'roadmap'} = $roadmap;
            delete_token($token);
        }

        if ($action eq 'delete') {
            check_token_data($token, 'delete_roadmap');

            my $roadmap =
                Bugzilla::Extension::Roadmap::Roadmap->check({ name => $input->{'name'} });
            $roadmap->remove_from_db;

            $vars->{'message'} = 'roadmap_deleted';
            $vars->{'roadmap'} = $roadmap;
            delete_token($token);
        }

	    $vars->{'roadmap_list'} = Bugzilla::Extension::Roadmap::Roadmap->match();

        print $cgi->header();    
        $template->process("admin/roadmap/list.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit; 
    }

    if ($page eq 'roadmap/create.html') {
        $can_edit || ThrowUserError("auth_failure", { group  => "editroadmaps",
                                                      action => "edit",
                                                      object => "roadmaps" });

	    $vars->{'token'} = issue_session_token('create_roadmap');

        print $cgi->header();
        $template->process("admin/roadmap/create.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit;
    } 

    if ($page eq 'roadmap/delete.html') {
        $can_edit || ThrowUserError("auth_failure", { group  => "editroadmaps",
                                                      action => "edit",
                                                      object => "roadmaps" });

        $vars->{'token'} = issue_session_token('delete_roadmap');

        $vars->{'roadmap'} =
            Bugzilla::Extension::Roadmap::Roadmap->check($input->{'name'});

        print $cgi->header();
        $template->process("admin/roadmap/confirm-delete.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit;
    }

    if ($page eq 'roadmap/edit.html') {
        $can_edit || ThrowUserError("auth_failure", { group  => "editroadmaps",
                                                      action => "edit",
                                                      object => "roadmaps" });

        my $action = $input->{'action'} || "";
        my $token  = $input->{'token'};

        my $roadmap =
            Bugzilla::Extension::Roadmap::Roadmap->check($input->{'name'});

        if ($action =~ /(add|delete|update)_milestone/) {
            $vars->{'changes'} = {};
        }

        if ($action eq 'delete_milestone') {
            check_token_data($token, 'delete_roadmap_milestone');

            my $milestone = 
                Bugzilla::Extension::Roadmap::Roadmap::Milestone->check(
                    { roadmap_id => $roadmap->id, name => $input->{'milestone_name'} });
            $milestone->remove_from_db();

            $vars->{'message'} = 'roadmap_milestone_deleted';
            $vars->{'milestone'} = $milestone;

            delete_token($token);
        }
    
        if ($action eq 'add_milestone') {
            check_token_data($token,  'edit_roadmap_milestone');

            my $milestone = Bugzilla::Extension::Roadmap::Roadmap::Milestone->create({
		        roadmap_id => $roadmap->id,
                name       => $input->{'milestone_name'}, 
                sortkey    => $input->{'milestone_sortkey'}, 
                deadline   => $input->{'milestone_deadline'},
                query      => $input->{'milestone_query'},                
            });

            $vars->{'message'} = 'roadmap_milestone_created';
            $vars->{'milestone'} = $milestone;
            
            delete_token($token);
        }

        if ($action eq 'update_milestone') {
            check_token_data($token, 'edit_roadmap_milestone');

            my $old_name = $input->{'milestone_old_name'};

            my $milestone = 
                Bugzilla::Extension::Roadmap::Roadmap::Milestone->check(
                    { name => $old_name, roadmap_id => $roadmap->id });

            $milestone->set_name($input->{'milestone_name'});
            $milestone->set_sortkey($input->{'milestone_sortkey'});
            $milestone->set_deadline($input->{'milestone_deadline'});
            $milestone->set_query($input->{'milestone_query'});
            my $changes = $milestone->update();

            if (%$changes) {
                $vars->{'message'} = 'roadmap_milestone_updated';
                $vars->{'changes'} = $changes;
            }

            $vars->{'milestone'} = $milestone;
 
            delete_token($token);
        }

        $vars->{'roadmap'} = $roadmap;
        $vars->{'token'}   = issue_session_token('edit_roadmap');

        print $cgi->header();
        $template->process("admin/roadmap/edit.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit; 
    }

    if ($page eq 'roadmap/edit-milestone.html') {
        $can_edit || ThrowUserError("auth_failure", { group  => "editroadmaps",
                                                      action => "edit",
                                                      object => "roadmaps" });

        $vars->{'token'} = issue_session_token('edit_roadmap_milestone');

        my $roadmap =
            Bugzilla::Extension::Roadmap::Roadmap->check($input->{'name'});

        if ($input->{'action'} ne 'new') {
            $vars->{'milestone'} = 
                Bugzilla::Extension::Roadmap::Roadmap::Milestone->check(
                    { name => $input->{'milestone_name'}, roadmap_id => $roadmap->id });
        }

        $vars->{'roadmap'} = $roadmap;
        $vars->{'action'} = $input->{'action'};

        print $cgi->header();
        $template->process("admin/roadmap/edit-milestone.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit;

    }

    if ($page eq 'roadmap/milestone-confirm-delete.html') {
        $can_edit || ThrowUserError("auth_failure",  { group  => "editroadmaps", 
                                                       action => "edit", 
                                                       object => "roadmaps" });

        $vars->{'token'} = issue_session_token('delete_roadmap_milestone');

        my $roadmap = 
            Bugzilla::Extension::Roadmap::Roadmap->check($input->{'name'});
        $vars->{'roadmap'} = $roadmap;

        $vars->{'milestone'} =
            Bugzilla::Extension::Roadmap::Roadmap::Milestone->check(
                { name => $input->{'milestone_name'}, roadmap_id => $roadmap->id });

        print $cgi->header();
        $template->process("admin/roadmap/milestone-confirm-delete.html.tmpl",  $vars)
            || ThrowTemplateError($template->error());
        exit;
    }
}

sub _update_boolean_charts {
    my ($cgi) = @_;

    # Creating new charts - if the cmd-add value is there, we define the field
    # value so the code sees it and creates the chart. It will attempt to select
    # "xyzzy" as the default, and fail. This is the correct behaviour.
    foreach my $cmd (grep(/^cmd-/, $cgi->param)) {
        if ($cmd =~ /^cmd-add(\d+)-(\d+)-(\d+)$/) {
            $cgi->param(-name => "field$1-$2-$3", -value => "xyzzy");
        }
    }

    if (!$cgi->param('field0-0-0')) {
        $cgi->param(-name => 'field0-0-0', -value => "xyzzy");
    }

    # Create data structure of boolean chart info. It's an array of arrays of
    # arrays - with the inner arrays having three members - field, type and
    # value.
    my @charts;
    for (my $chart = 0; $cgi->param("field$chart-0-0"); $chart++) {
        my @rows;
        for (my $row = 0; $cgi->param("field$chart-$row-0"); $row++) {
            my @cols;
            for (my $col = 0; $cgi->param("field$chart-$row-$col"); $col++) {
                my $value = $cgi->param("value$chart-$row-$col");
                if (!defined($value)) {
                    $value = '';
                }
                push(@cols, { field => $cgi->param("field$chart-$row-$col"),
                              type => $cgi->param("type$chart-$row-$col") || 'noop',
                              value => $value });
            }
            push(@rows, \@cols);
        }
        push(@charts, {'rows' => \@rows, 'negate' => scalar($cgi->param("negate$chart")) });
    }

    return \@charts;
}

__PACKAGE__->NAME;
