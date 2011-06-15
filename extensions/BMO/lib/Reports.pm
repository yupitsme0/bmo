# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.
#
# The Original Code is the BMO Bugzilla Extension.
#
# The Initial Developer of the Original Code is Byron Jones.  Portions created
# by the Initial Developer are Copyright (C) 2011 the Mozilla Foundation. All
# Rights Reserved.
#
# Contributor(s):
#   Byron Jones <glob@mozilla.com>

package Bugzilla::Extension::BMO::Reports;
use strict;

use Bugzilla::User;
use Bugzilla::Util qw(trim detaint_natural);
use Bugzilla::Error;
use Bugzilla::Constants;

use Date::Parse;
use DateTime;

use base qw(Exporter);

our @EXPORT_OK = qw(user_activity_report
                    triage_last_commenter_report
                    triage_stale_report);

sub user_activity_report {
    my ($vars) = @_;
    my $dbh = Bugzilla->dbh;
    my $input = Bugzilla->input_params;

    my @who = ();
    my $from = trim($input->{'from'});
    my $to = trim($input->{'to'});

    if ($input->{'action'} eq 'run') {
        if ($input->{'who'} eq '') {
            ThrowUserError('user_activity_missing_username');
        }
        Bugzilla::User::match_field({ 'who' => {'type' => 'multi'} });

        ThrowUserError('user_activity_missing_from_date') unless $from;
        my $from_time = str2time($from)
            or ThrowUserError('user_activity_invalid_date', { date => $from });
        my $from_dt = DateTime->from_epoch(epoch => $from_time)
                              ->set_time_zone('local')
                              ->truncate(to => 'day');
        $from = $from_dt->ymd();

        ThrowUserError('user_activity_missing_to_date') unless $to;
        my $to_time = str2time($to)
            or ThrowUserError('user_activity_invalid_date', { date => $to });
        my $to_dt = DateTime->from_epoch(epoch => $to_time)
                            ->set_time_zone('local')
                            ->truncate(to => 'day');
        $to = $to_dt->ymd();
        # add one day to include all activity that happened on the 'to' date
        $to_dt->add(days => 1);

        my ($activity_joins, $activity_where) = ('', '');
        my ($attachments_joins, $attachments_where) = ('', '');
        if (Bugzilla->params->{"insidergroup"}
            && !Bugzilla->user->in_group(Bugzilla->params->{'insidergroup'}))
        {
            $activity_joins = "LEFT JOIN attachments
                       ON attachments.attach_id = bugs_activity.attach_id";
            $activity_where = "AND COALESCE(attachments.isprivate, 0) = 0";
            $attachments_where = $activity_where;
        }

        my @who_bits;
        foreach my $who (
            ref $input->{'who'} 
            ? @{$input->{'who'}} 
            : $input->{'who'}
        ) {
            push @who, $who;
            push @who_bits, '?';
        }
        my $who_bits = join(',', @who_bits);

        if (!@who) {
            my $template = Bugzilla->template;
            my $cgi = Bugzilla->cgi;
            my $vars = {};
            $vars->{'script'}        = $cgi->url(-relative => 1);
            $vars->{'fields'}        = {};
            $vars->{'matches'}       = [];
            $vars->{'matchsuccess'}  = 0;
            $vars->{'matchmultiple'} = 1;
            print $cgi->header();
            $template->process("global/confirm-user-match.html.tmpl", $vars)
              || ThrowTemplateError($template->error());
            exit;
        }

        $from_dt = $from_dt->ymd() . ' 00:00:00';
        $to_dt = $to_dt->ymd() . ' 23:59:59';
        my @params;
        for (1..4) {
            push @params, @who;
            push @params, ($from_dt, $to_dt);
        }

        my $comment_filter = '';
        if (!Bugzilla->user->is_insider) {
            $comment_filter = 'AND longdescs.isprivate = 0';
        }

        my $query = "
        SELECT 
                   fielddefs.name,
                   bugs_activity.bug_id,
                   bugs_activity.attach_id,
                   ".$dbh->sql_date_format('bugs_activity.bug_when', '%Y.%m.%d %H:%i:%s')." AS ts,
                   bugs_activity.removed,
                   bugs_activity.added,
                   profiles.login_name,
                   bugs_activity.comment_id,
                   bugs_activity.bug_when
              FROM bugs_activity
                   $activity_joins
         LEFT JOIN fielddefs
                ON bugs_activity.fieldid = fielddefs.id
        INNER JOIN profiles
                ON profiles.userid = bugs_activity.who
             WHERE profiles.login_name IN ($who_bits)
                   AND bugs_activity.bug_when >= ? AND bugs_activity.bug_when <= ?
                   $activity_where

        UNION ALL

        SELECT 
                   'bug_id' AS name,
                   bugs.bug_id,
                   NULL AS attach_id,
                   ".$dbh->sql_date_format('bugs.creation_ts', '%Y.%m.%d %H:%i:%s')." AS ts,
                   '(new bug)' AS removed,
                   bugs.short_desc AS added,
                   profiles.login_name,
                   NULL AS comment_id,
                   bugs.creation_ts AS bug_when
              FROM bugs
        INNER JOIN profiles
                ON profiles.userid = bugs.reporter
             WHERE profiles.login_name IN ($who_bits)
                   AND bugs.creation_ts >= ? AND bugs.creation_ts <= ?

        UNION ALL

        SELECT 
                   'longdesc' AS name,
                   longdescs.bug_id,
                   NULL AS attach_id,
                   DATE_FORMAT(longdescs.bug_when, '%Y.%m.%d %H:%i:%s') AS ts,
                   '' AS removed,
                   '' AS added,
                   profiles.login_name,
                   longdescs.comment_id AS comment_id,
                   longdescs.bug_when
              FROM longdescs
        INNER JOIN profiles
                ON profiles.userid = longdescs.who
             WHERE profiles.login_name IN ($who_bits)
                   AND longdescs.bug_when >= ? AND longdescs.bug_when <= ?
                   $comment_filter

        UNION ALL

        SELECT 
                   'attachments.filename' AS name,
                   attachments.bug_id,
                   attachments.attach_id,
                   ".$dbh->sql_date_format('attachments.creation_ts', '%Y.%m.%d %H:%i:%s')." AS ts,
                   '' AS removed,
                   attachments.description AS added,
                   profiles.login_name,
                   NULL AS comment_id,
                   attachments.creation_ts AS bug_when
              FROM attachments
        INNER JOIN profiles
                ON profiles.userid = attachments.submitter_id
             WHERE profiles.login_name IN ($who_bits)
                   AND attachments.creation_ts >= ? AND attachments.creation_ts <= ?
                   $attachments_where

          ORDER BY bug_when ";

        my $list = $dbh->selectall_arrayref($query, undef, @params);

        my @operations;
        my $operation = {};
        my $changes = [];
        my $incomplete_data = 0;

        foreach my $entry (@$list) {
            my ($fieldname, $bugid, $attachid, $when, $removed, $added, $who,
                $comment_id) = @$entry;
            my %change;
            my $activity_visible = 1;

            next unless Bugzilla->user->can_see_bug($bugid);

            # check if the user should see this field's activity
            if ($fieldname eq 'remaining_time'
                || $fieldname eq 'estimated_time'
                || $fieldname eq 'work_time'
                || $fieldname eq 'deadline')
            {
                $activity_visible = Bugzilla->user->is_timetracker;
            }
            elsif ($fieldname eq 'longdescs.isprivate'
                    && !Bugzilla->user->is_insider 
                    && $added) 
            { 
                $activity_visible = 0;
            } 
            else {
                $activity_visible = 1;
            }

            if ($activity_visible) {
                # Check for the results of an old Bugzilla data corruption bug
                if (($added eq '?' && $removed eq '?')
                    || ($added =~ /^\? / || $removed =~ /^\? /)) {
                    $incomplete_data = 1;
                }

                # An operation, done by 'who' at time 'when', has a number of
                # 'changes' associated with it.
                # If this is the start of a new operation, store the data from the
                # previous one, and set up the new one.
                if ($operation->{'who'}
                    && ($who ne $operation->{'who'}
                        || $when ne $operation->{'when'}))
                {
                    $operation->{'changes'} = $changes;
                    push (@operations, $operation);
                    $operation = {};
                    $changes = [];
                }

                $operation->{'bug'} = $bugid;
                $operation->{'who'} = $who;
                $operation->{'when'} = $when;

                $change{'fieldname'} = $fieldname;
                $change{'attachid'} = $attachid;
                $change{'removed'} = $removed;
                $change{'added'} = $added;
                
                if ($comment_id) {
                    $change{'comment'} = Bugzilla::Comment->new($comment_id);
                    next if $change{'comment'}->count == 0;
                }

                push (@$changes, \%change);
            }
        }

        if ($operation->{'who'}) {
            $operation->{'changes'} = $changes;
            push (@operations, $operation);
        }

        $vars->{'incomplete_data'} = $incomplete_data;
        $vars->{'operations'} = \@operations;

    } else {

        if ($from eq '') {
            my ($yy, $mm) = (localtime)[5, 4];
            $from = sprintf("%4d-%02d-01", $yy + 1900, $mm + 1);
        }
        if ($to eq '') {
            my ($yy, $mm, $dd) = (localtime)[5, 4, 3];
            $to = sprintf("%4d-%02d-%02d", $yy + 1900, $mm + 1, $dd);
        }
    }

    $vars->{'action'} = $input->{'action'};
    $vars->{'who'} = join(',', @who);
    $vars->{'from'} = $from;
    $vars->{'to'} = $to;
}

sub triage_last_commenter_report {
    my ($vars) = @_;

    my $input = Bugzilla->input_params;
    my $commenter = $input->{commenter};
    $vars->{commenter} = $commenter;

    _triage_report($vars, sub {
        my $bug = shift;
        return 0 if $bug->{comment_count} <= 1;

        if ($commenter eq 'reporter') {
            return $bug->{commenter}->id == $bug->{reporter}->id;
        }

        if ($commenter eq 'canconfirm') {
            return ($bug->{commenter}->id == $bug->{reporter}->id)
                || !$bug->{commenter}->in_group('canconfirm');
        }

        return 0;
    });
}

sub triage_stale_report {
    my ($vars) = @_;

    my $input = Bugzilla->input_params;
    my $period = $input->{period};

    detaint_natural($period);
    $period = 14 if $period < 14;
    $vars->{period} = $period;

    my $now = (time);
    _triage_report($vars, sub {
        my $bug = shift;
        my $comment_time = str2time($bug->{comment_ts})
            or return 0;
        return $now - $comment_time > 60 * 60 * 24 * $period;
    });
}

sub _triage_report {
    my ($vars, $filter) = @_;
    my $dbh = Bugzilla->dbh;
    my $input = Bugzilla->input_params;
    my $user = Bugzilla->user;

    my @selectable_products = sort { lc($a->name) cmp lc($b->name) }
        @{$user->get_selectable_products};
    Bugzilla::Product::preload(\@selectable_products);
    $vars->{'products'} = \@selectable_products;

    if (Bugzilla->params->{'useclassification'}) {
        $vars->{'classifications'} = $user->get_selectable_classifications;
    }

    my @products = @{Bugzilla->user->get_accessible_products()};
    @products = sort { lc($a->name) cmp lc($b->name) } @products;
    $vars->{'accessible_products'} = \@products;

    if ($input->{'action'} eq 'run' && $input->{'product'}) {
        my $query = "
              SELECT bug_id, short_desc, reporter, creation_ts
                FROM bugs
               WHERE product_id = ?
                     AND bug_status = 'UNCONFIRMED'
            ORDER BY creation_ts
        ";
        my ($product_id) = $input->{product} =~ /(\d+)/;
        my $list = $dbh->selectall_arrayref($query, undef, $product_id);

        my @bugs;

        my $comment_count_sql = "
            SELECT COUNT(*)
              FROM longdescs
             WHERE bug_id = ?
        ";

        my $comment_sql = "
              SELECT who, bug_when, type, thetext, extra_data
                FROM longdescs
               WHERE bug_id = ?
        ";
        if (!Bugzilla->user->is_insider) {
            $comment_sql .= " AND isprivate = 0 ";
        }
        $comment_sql .= "
            ORDER BY bug_when DESC
               LIMIT 1
        ";

        my $attach_sql = "
            SELECT description
              FROM attachments
             WHERE attach_id = ?
        ";

        my $commenter = $input->{commenter};
        foreach my $entry (@$list) {
            my ($bug_id, $summary, $reporter_id, $creation_ts) = @$entry;

            next unless $user->can_see_bug($bug_id);

            my ($comment_count) = $dbh->selectrow_array($comment_count_sql, undef, $bug_id);
            my ($commenter_id, $comment_ts, $type, $comment, $extra) = $dbh->selectrow_array($comment_sql, undef, $bug_id);

            if ($type == CMT_ATTACHMENT_CREATED) {
                ($comment) = $dbh->selectrow_array($attach_sql, undef, $extra);
                $comment = "(Attachment) " . $comment;
            }

            if (length($comment) > 80) {
                $comment = substr($comment, 0, 80) . '...';
            }

            my $bug = {};
            $bug->{id} = $bug_id;
            $bug->{summary} = $summary;
            $bug->{reporter} = Bugzilla::User->new($reporter_id);
            $bug->{creation_ts} = $creation_ts;
            $bug->{commenter} = Bugzilla::User->new($commenter_id);
            $bug->{comment_ts} = $comment_ts;
            $bug->{comment} = $comment;
            $bug->{comment_count} = $comment_count;

            next unless &$filter($bug);
            push @bugs, $bug;
        }

        @bugs = sort { $b->{comment_ts} cmp $a->{comment_ts} } @bugs;

        $vars->{bugs} = \@bugs;
    } else {
        $input->{action} = '';
    }

    foreach my $name (qw(action product)) {
        $vars->{$name} = $input->{$name};
    }
}

1;
