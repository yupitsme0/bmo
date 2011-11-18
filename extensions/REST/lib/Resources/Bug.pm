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

package Bugzilla::Extension::REST::Resources::Bug;

use strict;

use base qw(Exporter Bugzilla::WebService);

use Bugzilla;
use Bugzilla::CGI;
use Bugzilla::Constants;
use Bugzilla::Search;
use Bugzilla::Util qw(correct_urlbase);

use Bugzilla::WebService::Bug;

use Bugzilla::Extension::REST::Util qw(inherit_package adjust_fields ref_urlbase remove_immutables);
use Bugzilla::Extension::REST::Constants;

use Tie::IxHash;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);

use constant DATE_FIELDS => {
    comments => ['new_since'], 
    search   => ['last_change_time',  'creation_time'], 
};

use constant BASE64_FIELDS => {
    add_attachment => ['data'], 
};

#############
# Resources #
#############

# IxHash keeps them in insertion order, and so we get regexp priorities right.
our $_resources = {};
tie(%$_resources, "Tie::IxHash",
    qr{/bug$} => { 
        GET  => 'bug_GET',
        POST => 'bug_POST',
    },
    qr{/bug/([^/]+)$} => {
        GET => 'one_bug_GET',
        PUT => 'bug_PUT',
    },
    qr{/bug/([^/]+)/comment$} => { 
        GET  => 'comment_GET',
        POST => 'comment_POST'  
    },
    qr{/bug/([^/]+)/history$}  => { 
        GET => 'history_GET'
    },
    qr{/bug/([^/]+)/attachment$} =>  {
        GET  => 'attachment_GET',
        POST => 'attachment_POST',
    },
    qr{/attachment/([^/]+)$} =>  {
        GET => 'one_attachment_GET'
    }, 
    qr{/bug/([^/]+)/flag$} => {
        GET => 'flag_GET',
    }, 
    qr{/count$} => {
        GET => 'count_GET', 
    }
);

sub resources { return $_resources };

###########
# Methods #
###########

sub bug_GET {
    my ($self, $params) = @_;
    my $dbh = Bugzilla->dbh;

    my @adjusted_bugs = map { $self->_fix_bug($params, $_) } 
                        @{ $self->_do_search($params) };

    $self->_bz_response_code(STATUS_OK);
    return { bugs => \@adjusted_bugs };
}

# Return a single bug report
sub one_bug_GET {
    my ($self, $params) = @_;

    $params->{'ids'} = [ $self->_bz_regex_matches->[0] ];
    
    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->get($params);

    my $adjusted_bug = $self->_fix_bug($params, $result->{'bugs'}[0]);

    $self->_bz_response_code(STATUS_OK);
    return $adjusted_bug;
}

# Update attributes of a single bug
sub bug_PUT {
    my ($self, $params) = @_;

    $params->{'ids'} = [ $self->_bz_regex_matches->[0] ];

    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->update($params);

    $self->_bz_response_code(STATUS_OK);
    return { "ok" => 1 };
}

# Create a new bug
sub bug_POST {
    my ($self, $params) = @_;
    my $extra = {};

    # Downgrade user objects to email addresses
    foreach my $person ('assigned_to', 'reporter', 'qa_contact') {
        if ($params->{$person}) {
            $params->{$person} = $params->{$person}->{'name'};
        }
    }

    if ($params->{'cc'}) {
        my @names = map ( { $_->{'name'} } @{$params->{'cc'}});
        $params->{'cc'} = \@names;
    }

    # For consistency, we take initial comment in comments array
    delete $params->{'description'};
    if (ref $params->{'comments'}) {
        $params->{'description'} = $params->{'comments'}->[0]->{'text'};
        delete $params->{'comments'};
    }

    # Remove fields the XML-RPC interface will object to
    # We list legal fields rather than illegal ones because enumerating badness
    # breaks more easily. This list straight from the 3.4 documentation.
    my @legalfields = qw(product component summary version description 
                         op_sys platform priority severity alias assigned_to 
                         cc comment_is_private groups qa_contact status 
                         target_milestone);

    my @customfields = map { $_->name } Bugzilla->active_custom_fields;

    foreach my $field (keys %$params) {
        if (!grep($_ eq $field, (@legalfields, @customfields))) {
            $extra->{$field} = $params->{$field};
            delete $params->{$field};
        }
    }

    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->create($params);

    my $bug_id = $result->{'id'};
    my $ref = ref_urlbase() . "/bug/$bug_id";

    # We do a Bug.update if we have any extra fields
    remove_immutables($extra);

    # We shouldn't have one of these, but let's not mid-air if they send one
    delete $extra->{'last_change_time'};

    if (%$extra) {
        $extra->{'ids'} = [ $bug_id ];
        $self->update($extra);
    }

    $self->_bz_response_code(STATUS_CREATED);
    return { ref => $ref, id => $bug_id };
}

# Get all comments for given bug
sub comment_GET {
    my ($self, $params) = @_;

    my $bug_id = $self->_bz_regex_matches->[0];
    $params->{'ids'} = [ $bug_id ];
    
    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->comments($params);

    my @adjusted_comments = map { $self->_fix_comment($params, $_) }
                            @{ $result->{bugs}{$bug_id}{comments} };

    $self->_bz_response_code(STATUS_OK);
    return { comments => \@adjusted_comments };
}

# Create a new comment for a given bug
sub comment_POST {
    my ($self, $params) = @_;
    my $bug_id = $self->_bz_regex_matches->[0];
    $params->{'id'} = $bug_id;

    # Backwards compat
    $params->{'comment'} = $params->{'text'} if $params->{'text'};

    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->add_comment($params);

    $self->_bz_response_code(STATUS_OK);
    # Comments don't have their own refs, so pass ref of comment list
    return { ref => ref_urlbase() . "/bug/$bug_id/comment" }; 
}

# Get all history for a given bug
sub history_GET {
    my ($self, $params) = @_;

    my $bug_id = $self->_bz_regex_matches->[0];
    $params->{'ids'} = [ $bug_id ];

    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->history($params);

    my @adjusted_history;
    foreach my $changeset (@{ $result->{bugs}[0]{history} }) {
        $changeset->{bug_id} = $bug_id;
        push(@adjusted_history, $self->_fix_changeset($params, $changeset));
    }

    $self->_bz_response_code(STATUS_OK);
    return { history => \@adjusted_history };
}

# Get attachments for a given bug
sub attachment_GET {
    my ($self, $params) = @_;

    my $bug_id = $self->_bz_regex_matches->[0];
    $params->{'ids'} = [ $bug_id ];
    $params->{'exclude_fields'} = [ 'data' ]
        if !$params->{attachmentdata};

    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    my $result = $self->attachments($params);

    my @adjusted_attachments = map { $self->_fix_attachment($params, $_) } 
                               @{ $result->{bugs}{$bug_id} };

    $self->_bz_response_code(STATUS_OK);
    return { attachments => \@adjusted_attachments };
}

# Get a single attachment
sub one_attachment_GET {
    my ($self,  $params) = @_;

    my $attach_id = $self->_bz_regex_matches->[0];
    $params->{attachment_ids} = [ $attach_id ];
    $params->{'exclude_fields'} = [ 'data' ]
        if !$params->{attachmentdata};

    $self = inherit_package($self,  'Bugzilla::WebService::Bug');
    my $result = $self->attachments($params);

    my $adjusted_attachment 
        = $self->_fix_attachment($params, $result->{attachments}{$attach_id});

    $self->_bz_response_code(STATUS_OK);
    return $adjusted_attachment;
}

# Create a new attachment for a given bug
sub attachment_POST {
    my ($self, $params) = @_;
    $self = inherit_package($self, 'Bugzilla::WebService::Bug');
    $self->_bz_response_code(STATUS_CREATED);
    return $self->attachment($params);
}

# Get all currently set flags for a given bug
sub flag_GET {
    my ($self, $params) = @_;

    my $bug_id = $self->_bz_regex_matches->[0];

    # Retrieve normal Bug flags
    my $bug = Bugzilla::Bug->check($bug_id);
    my $flags = $bug->flags;

    # Add any attachment flags as well
    foreach my $attachment (@{ $bug->attachments }) {
        push(@$flags, @{ $attachment->flags });
    }

    my @adjusted_flags = map { $self->_fix_flag($params, $_) }
                         @$flags;

    $self->_bz_response_code(STATUS_OK);
    return { flags => \@adjusted_flags };
}

# Get a count of bugs based on the search paranms. If a x, y, or z
# axis if provided then return the counts as a chart.

sub count {
    my ($self, $params) = @_;

    my $col_field = delete $params->{'x_axis_field'};
    my $row_field = delete $params->{'y_axis_field'};
    my $tbl_field = delete $params->{'z_axis_field'};
   
    my $dimensions = $col_field ?
                     $row_field ?
                     $tbl_field ? 3 : 2 : 1 : 0;

    # Use bug status if no axis was provided
    if ($dimensions == 0) {
        $row_field = 'status';
    }
    elsif ($dimensions == 1) {
        # 1D *tables* should be displayed vertically (with a row_field only)
        $row_field = $col_field;
        $col_field = '';
    }

    # Call _do_search to get our bug list
    my $bugs = $self->_do_search($params);

    # We detect a numerical field, and sort appropriately, 
    # if all the values are numeric.
    my $col_isnumeric = 1;
    my $row_isnumeric = 1;
    my $tbl_isnumeric = 1;

    my (%data, %names);
    foreach my $bug (@$bugs) {
        # Values can be XMLRPC::Data types so we test for that
        my $row = $bug->{$row_field}; 
        my $col = $bug->{$col_field};
        my $tbl = $bug->{$tbl_field};

        $data{$tbl}{$col}{$row}++;
        $names{"col"}{$col}++;
        $names{"row"}{$row}++;
        $names{"tbl"}{$tbl}++;

        $col_isnumeric &&= ($col =~ /^-?\d+(\.\d+)?$/o);
        $row_isnumeric &&= ($row =~ /^-?\d+(\.\d+)?$/o);
        $tbl_isnumeric &&= ($tbl =~ /^-?\d+(\.\d+)?$/o);
    }

    my @col_names = @{_get_names($names{"col"}, $col_isnumeric, $col_field)};
    my @row_names = @{_get_names($names{"row"}, $row_isnumeric, $row_field)};
    my @tbl_names = @{_get_names($names{"tbl"}, $tbl_isnumeric, $tbl_field)};

    my @data;
    foreach my $tbl (@tbl_names) {
        my @tbl_data;
        foreach my $row (@row_names) {
            my @col_data;
            foreach my $col (@col_names) {
                $data{$tbl}{$col}{$row} = $data{$tbl}{$col}{$row} || 0;
                push(@col_data, $data{$tbl}{$col}{$row});
            }
            push(@tbl_data, \@col_data);
        }
        unshift(@data, \@tbl_data);
    }

    my $result;
    if ($dimensions == 0) {
        # Just return the sum of the counts if dimension == 0
        my $sum = 0;
        foreach my $list (@{ pop @data }) {
            $sum += $list->[0];
        }
        $result = {
            data => $sum,
        };
    }
    elsif ($dimensions == 1) {
        # Convert to a single list of counts if dimension == 1
        my @array;
        foreach my $list (@{ pop @data }) {
            push(@array, $list->[0]);
        }
        $result = {
            x_labels => \@row_names,
            data     => \@array || []
        };
    }
    elsif ($dimensions == 2) {
        $result = {
            x_labels => \@col_names,
            y_labels => \@row_names,
            data     => pop @data || [[]]
        };
    }
    elsif ($dimensions == 3) {
        $result = {
            x_labels => \@col_names,
            y_labels => \@row_names,
            z_labels => \@tbl_names,
            data     => @data ? \@data : [[[]]]
        };
    }

    $self->_bz_response_code(STATUS_OK);
    return $result;
}

##################
# Helper Methods #
##################

sub _do_search {
    my ($self, $params) = @_;

    my $columns = Bugzilla::Search::COLUMNS;
    my @selectcolumns = grep($_ ne 'short_short_desc', keys(%$columns));

    # Remove the timetracking columns if they are not a part of the group
    # (happens if a user had access to time tracking and it was revoked/disabled)
    if (!Bugzilla->user->is_timetracker) {
        @selectcolumns = grep($_ ne 'estimated_time', @selectcolumns);
        @selectcolumns = grep($_ ne 'remaining_time', @selectcolumns);
        @selectcolumns = grep($_ ne 'actual_time', @selectcolumns);
        @selectcolumns = grep($_ ne 'percentage_complete', @selectcolumns);
        @selectcolumns = grep($_ ne 'deadline', @selectcolumns);
    }

    # Remove the relevance column if not doing a fulltext search.
    @selectcolumns = grep($_ ne 'relevance', @selectcolumns);

    # Make sure that the login_name version of a field is always also
    # requested if the realname version is requested, so that we can
    # display the login name when the realname is empty.
    my @realname_fields = grep(/_realname$/, @selectcolumns);
    foreach my $item (@realname_fields) {
        my $login_field = $item;
        $login_field =~ s/_realname$//;
        if (!grep($_ eq $login_field, @selectcolumns)) {
            push(@selectcolumns, $login_field);
        }
    }

    my $search = new Bugzilla::Search('fields' => \@selectcolumns,
                                      'params' => Bugzilla::CGI->new($params));
    my $query = $search->getSQL(); 

    my $dbh = Bugzilla->switch_to_shadow_db();
    my $buglist_sth = $dbh->prepare($query);
    $buglist_sth->execute();

    my @bugs;
    while (my @row = $buglist_sth->fetchrow_array()) {
        my $bug = {};
        foreach my $column (@selectcolumns) {
            $bug->{$column} = shift @row;
        }

        $bug->{'secure_mode'} = undef;
        $bug->{'ref'} = ref_urlbase() . "/bug/" . $bug->{'id'};

        push(@bugs, $bug);
    }

    my %min_membercontrol;
    if (scalar @bugs) {
        my $sth = $dbh->prepare(
            "SELECT DISTINCT bugs.bug_id, MIN(group_control_map.membercontrol) " .
              "FROM bugs " .
        "INNER JOIN bug_group_map " .
                "ON bugs.bug_id = bug_group_map.bug_id " .
         "LEFT JOIN group_control_map " .
                "ON group_control_map.product_id = bugs.product_id " .
               "AND group_control_map.group_id = bug_group_map.group_id " .
             "WHERE " . $dbh->sql_in('bugs.bug_id', map { $_->{'bug_id'} } @bugs) .
            $dbh->sql_group_by('bugs.bug_id'));
        $sth->execute();
        while (my ($bug_id, $min_membercontrol) = $sth->fetchrow_array()) {
            $min_membercontrol{$bug_id} = $min_membercontrol || CONTROLMAPNA;
        }
        foreach my $bug (@bugs) {
            next unless defined($min_membercontrol{$bug->{'bug_id'}});
            if ($min_membercontrol{$bug->{'bug_id'}} == CONTROLMAPMANDATORY) {
                $bug->{'secure_mode'} = 'implied';
            }
            else {
                $bug->{'secure_mode'} = 'manual';
            }
        }
    }

    return \@bugs;
}

sub _fix_bug {
    my ($self, $params, $bug) = @_;

    $bug = adjust_fields($params, $bug);

    $bug->{ref} = ref_urlbase() . "/bug/" . $bug->{bug_id};

    return $bug;    
}

sub _fix_comment {
    my ($self, $params, $comment) = @_;

    $comment = adjust_fields($params, $comment);

    $comment->{bug_ref} = ref_urlbase() . "/bug/" . $comment->{bug_id};
    $comment->{creator} = {
        ref => ref_urlbase() . "/user/" . $comment->{creator}, 
        name => $comment->{creator}
    };
    $comment->{creation_time} = $comment->{time};
                                  
    delete $comment->{author};
    delete $comment->{time};
    delete $comment->{attachment_id};

    return $comment;
}

sub _fix_changeset {
    my ($self, $params, $changeset) = @_;

    $changeset = adjust_fields($params, $changeset);

    $changeset->{bug_ref} = ref_urlbase() . "/bug/" . $changeset->{bug_id};
    $changeset->{changer} = {
        ref => ref_urlbase() . "/user/" . $changeset->{who},
        name => $changeset->{who}
    };
    $changeset->{change_time} = $changeset->{when};

    delete $changeset->{who};
    delete $changeset->{when};

    return $changeset;
}

sub _fix_attachment {
    my ($self, $params, $attachment) = @_;

    $attachment = adjust_fields($params, $attachment, ["data", "encoding"]);

    $attachment->{bug_ref}  = ref_urlbase() . "/bug/" . $attachment->{bug_id};
    $attachment->{ref}      = ref_urlbase() . "/attachment/" . $attachment->{id};
    $attachment->{attacher} = {
         ref  => ref_urlbase() . "/user/" . $attachment->{attacher},
         name => $attachment->{attacher}
    };

    $attachment->{is_patch}    = $self->type('boolean', $attachment->{is_patch});
    $attachment->{is_private}  = $self->type('boolean', $attachment->{is_private});
    $attachment->{is_obsolete} = $self->type('boolean', $attachment->{is_obsolete});
    $attachment->{is_url}      = $self->type('boolean', $attachment->{is_url});
   
    return $attachment; 
}

sub _fix_flag {
    my ($self, $params, $flag) = @_;

    $flag = adjust_fields($params, $flag);

    $flag->{bug_ref} = ref_urlbase() . "/bug/" . $flag->{bug_id};
    $flag->{setter} = {
        ref => ref_urlbase() . "/user/" . $flag->setter->login,
        name => $flag->setter->login
    };
    if ($flag->{requestee_id}) {
        $flag->{requestee} = {
            ref  => ref_urlbase() . "/user/" . $flag->requestee->login,
            name => $flag->requestee->login
        };
    }
    $flag->{name} = $flag->name;

    delete $flag->{type};
    delete $flag->{attach_id} if !$flag->{attach_id};
    delete $flag->{setter_id};
    delete $flag->{requestee_id};

    return $flag;
}

sub _get_names {
    my ($names, $isnumeric, $field) = @_;
 
    my $select_fields = Bugzilla->fields({ is_select => 1 });
   
    my %fields;
    foreach my $field (@$select_fields) {
        my @names = map { $_->name } Bugzilla::Field::Choice->type($field)->get_all();
        unshift @names, ' ' if $field->name eq 'resolution'; 
        $fields{$field->name} = [ uniq @names ];
    } 
    
    my $field_list = $fields{$field};
    
    my @sorted;
    if ($field_list) {
        my @unsorted = keys %{$names};
        foreach my $item (@$field_list) {
            push(@sorted, $item) if grep { $_ eq $item } @unsorted;
        }
    }  
    elsif ($isnumeric) {
        sub numerically { $a <=> $b }
        @sorted = sort numerically keys(%{$names});
    } else {
        @sorted = sort(keys(%{$names}));
    }
    
    return \@sorted;
}

1;
