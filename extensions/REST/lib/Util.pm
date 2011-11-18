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

package Bugzilla::Extension::REST::Util;

use strict;
use warnings;

use Bugzilla::Util qw(correct_urlbase);

use Data::Dumper;
use LWP::UserAgent;
use JSON;
use Date::Parse;
use DateTime;
use URI::Escape;

use base qw(Exporter);
our @EXPORT = qw(
    inherit_package
    fix_include_exclude
    $OLD2NEW
    $NEW2OLD
    $NEWTYPES2OLD
    $OLDATTACH2NEW
    $NEWATTACH2OLD
    change_field_name
    remove_immutables
    arraydiff2addremove
    fixup_bug
    fixup_xml_bug
    fix_person
    fix_comments
    fix_time
    unfix_time
    new2old
    extract_cc_names
    xmlrpc_error2error
    xml_error2error
    http_result2error
    change_query_param_name
    flags2hash
    stringify
    stringify_req
    stringify_hashref
    jsonify
    downgrade_search_url
    exclude_fields
    get_include_fields
    adjust_fields
    ref_urlbase
);

# Field name translation - used on loads of interfaces
our $OLD2NEW = {
    'opendate'            => 'creation_time', # query
    'creation_ts'         => 'creation_time',
    'changeddate'         => 'last_change_time', # query
    'delta_ts'            => 'last_change_time',
    'bug_id'              => 'id',
    'rep_platform'        => 'platform',
    'bug_severity'        => 'severity',
    'bug_status'          => 'status',     
    'short_desc'          => 'summary',
    'short_short_desc'    => 'summary',
    'bug_file_loc'        => 'url',
    'status_whiteboard'   => 'whiteboard',
    'cclist_accessible'   => 'is_cc_accessible',
    'reporter_accessible' => 'is_reporter_accessible',
    'everconfirmed'       => 'is_everconfirmed',
    'dependson'           => 'depends_on',
    'blocked'             => 'blocks',
    'attachment'          => 'attachments',
    'flag'                => 'flags',
    'flagtypes.name'      => 'flag',
    'bug_group'           => 'group',
    'group'               => 'groups',
    'longdesc'            => 'comment',
    'bug_file_loc_type'   => 'url_type',
    'bugidtype'           => 'id_mode',
    'longdesc_type'       => 'comment_type',
    'short_desc_type'     => 'summary_type',
    'status_whiteboard_type' => 'whiteboard_type',
    'emailassigned_to1'   => 'email1_assigned_to',
    'emailassigned_to2'   => 'email2_assigned_to',
    'emailcc1'            => 'email1_cc',
    'emailcc2'            => 'email2_cc',
    'emailqa_contact1'    => 'email1_qa_contact',
    'emailqa_contact2'    => 'email2_qa_contact',
    'emailreporter1'      => 'email1_reporter',
    'emailreporter2'      => 'email2_reporter',
    'emaillongdesc1'      => 'email1_comment_author',
    'emaillongdesc2'      => 'email2_comment_author',
    'emailtype1'          => 'email1_type',
    'emailtype2'          => 'email2_type',
    'chfieldfrom'         => 'changed_after',
    'chfieldto'           => 'changed_before',
    'chfield'             => 'changed_field',
    'chfieldvalue'        => 'changed_field_to',
    'deadlinefrom'        => 'deadline_after',
    'deadlineto'          => 'deadline_before',
    'attach_data.thedata' => 'attachment.data',
    'longdescs.isprivate' => 'comment.is_private',
    'commenter'           => 'comment.author',
    'flagtypes.name'      => 'flag',
    'requestees.login_name' => 'flag.requestee',
    'setters.login_name'  => 'flag.setter',
    'days_elapsed'        => 'idle',
    'owner_idle_time'     => 'assignee_idle',
    'dup_id'              => 'dupe_of',
    'isopened'            => 'is_open',
    'flag_type'           => 'flag_types',
};

our $OLDATTACH2NEW = {
    'submitter'   => 'attacher',
    'description' => 'description',
    'filename'    => 'file_name',
    'delta_ts'    => 'last_change_time',
    'isurl'       => 'is_url',
    'isobsolete'  => 'is_obsolete',
    'ispatch'     => 'is_patch',
    'isprivate'   => 'is_private',
    'mimetype'    => 'content_type',
    'contenttypeentry' => 'content_type',
    'date'        => 'creation_time',
    'attachid'    => 'id',
    'desc'        => 'description',
    'flag'        => 'flags',
    'type'        => 'content_type'
};

# Add attachment stuff to the main hash too, for queries - but with prefixes
foreach my $key (keys %$OLDATTACH2NEW) {
    $OLD2NEW->{'attachments.' . $key} = 'attachment.' . $OLDATTACH2NEW->{$key};
}

# Do a reverse mapping as well
our $NEW2OLD = { reverse %$OLD2NEW };

# A bit of a hack to make sure the reverse mapping is right in cases where
# the forward mapping maps multiple keys to a single value.
$NEW2OLD->{'creation_time'} = 'creation_ts';
$NEW2OLD->{'last_change_time'} = 'delta_ts';
$NEW2OLD->{'flag'} = 'flagtypes.name';
$NEW2OLD->{'summary'} = 'short_desc';
$NEW2OLD->{'attachment.content_type'} = 'attachments.mimetype';

our $NEWATTACH2OLD = { reverse %$OLDATTACH2NEW };

$NEWATTACH2OLD->{'content_type'} = 'contenttypeentry';
$NEWATTACH2OLD->{'description'} = 'description';

our $NEWTYPES2OLD = {
    'equals'                  => 'equals',
    'not_equals'              => 'notequals',
    'equals_any'              => 'anyexact',
    'contains'                => 'substring',
    'not_contains'            => 'notsubstring',
    'case_contains'           => 'casesubstring',
    'contains_any'            => 'anywordssubstr',
    'not_contains_any'        => 'nowordssubstr',
    'contains_all'            => 'allwordssubstr',
    'contains_any_words'      => 'anywords',
    'not_contains_any_words'  => 'nowords',
    'contains_all_words'      => 'allwords',
    'regex'                   => 'regexp',
    'not_regex'               => 'notregexp',
    'less_than'               => 'lessthan',
    'greater_than'            => 'greaterthan',
    'changed_before'          => 'changedbefore',
    'changed_after'           => 'changedafter',
    'changed_from'            => 'changedfrom',
    'changed_to'              => 'changedto',
    'changed_by'              => 'changedby',
    'matches'                 => 'matches'
};

# Return an URL base appropriate for constructing a ref link 
# normally required by REST API calls.
sub ref_urlbase {
    return correct_urlbase() . "rest.cgi";
}

# Add the capabilities of the class
# to the current instance
sub inherit_package {
    my ($self, $pkg) = @_;
    my $new_class = ref($self) . '::' . $pkg;
    my $isa_string = 'our @ISA = qw(' . ref($self) . " $pkg)";
    eval "package $new_class;$isa_string;";
    bless $self, $new_class;
    return $self;
}

#sub fix_include_exclude {
#    my ($params) = @_;
#
#    # _all is same as default columns
#    delete $params->{'include_fields'} if $params->{'include_fields'} eq '_all';
#
#    if ($params->{'include_fields'} && !ref $params->{'include_fields'}) {
#        $params->{'include_fields'} = [ split(/[\s+,]/, $params->{'include_fields'}) ];
#    }   
#    if ($params->{'exclude_fields'} && !ref $params->{'exclude_fields'}) {
#        $params->{'exclude_fields'} = [ split(/[\s+,]/, $params->{'exclude_fields'}) ];
#    }
#    
#    return $params;
#}
#
#sub change_field_name {
#    my ($hashref, $from, $to) = @_;
#    
#    if (defined($hashref->{$from})) {
#        $hashref->{$to} = delete $hashref->{$from};
#    }
#}
#
#sub change_query_param_name {
#    my ($url, $from, $to) = @_;
#    
#    if ($url->query_param($from)) {
#        $url->query_param_append($to, $url->query_param_delete($from));
#    }
#}
#
#sub downgrade_query {
#    my ($url) = shift;
#    
#    foreach my $field (keys %{$OLD2NEW}) {
#        change_field_name($url, $field, $OLD2NEW->{$field});
#    }
#}
#
#sub new2old {
#    return $NEW2OLD->{$_[0]} || $_[0];
#}
#
#sub jsonify {
#    my ($ref) = @_;
#    my $jsonifier = new JSON;
#    $jsonifier->utf8->indent(0);
#    return $jsonifier->encode($ref);
#}

sub remove_immutables {
    my ($bug) = @_;
    
    # Stuff you can't change, or change directly
    my @immutable = ('reporter', 'creation_time', 'id', 
                     'ref', 'is_everconfirmed', 'remaining_time', 
                     'actual_time', 'percentage_complete');
    foreach my $field (@immutable) {
        delete $bug->{$field};
    }
}
  
#sub extract_cc_names {
#    my ($bug) = shift;
#    my @ccnames;
#    
#    if ($bug->{'cc'}) {
#        foreach my $cc (@{$bug->{'cc'}}) {
#            push(@ccnames, $cc->{'name'});
#        }
#    }
#    
#    return \@ccnames;
#}

# Takes two arrays, diffs them, and converts them into "add" and "remove"
# params in a hash using the keys given. Useful for cc and see_also.
#sub arraydiff2addremove {
#     my ($before, $after, $hash, $addkey, $removekey) = @_;
#  
#    my ($added, $deleted) = arraydiff($before, $after);
#  
#    # Add is a comma-separated list...
#    $hash->{$addkey} = join(", ", @$added);
#
#    # Remove is separate parameters.
#    if (@$deleted) {
#        $hash->{$removekey} = $deleted;
#    }
#}
#
#sub arraydiff {
#    my ($before, $after) = @_;
#    
#    my $added = [];
#    my $deleted = [];
#    
#    if (ref $before) {
#      if (ref $after) {
#            # Before and after
#            my $diff = Array::Diff->diff($before, $after);
#            $added = $diff->added;
#            $deleted = $diff->deleted;
#        }
#        else {
#            # Before, no after
#            $deleted = $before;
#        }
#    }
#    elsif (ref($after)) {
#        # After, no before
#        $added = $after;
#    }
#    
#    return ($added, $deleted);
#}

##############################################################################
# Fixing bug structures
##############################################################################
# Used both for legacy XML interface and for CSV list interface
#sub fixup_bug {
#    my ($cgi, $bug) = @_;
#    
#    # The old interfaces we are using don't use the same friendly field names
#    # as the current XML-RPC API. So we need fixup functions. The simplest is 
#    # just a translation table.
#    foreach my $field (keys %{$OLD2NEW}) {
#        change_field_name($bug, $field, $OLD2NEW->{$field});
#    }
#    
#    # Split keywords into array
#    if (defined($bug->{'keywords'})) {
#        my @keywords = split(/,\s*/, $bug->{'keywords'});
#        $bug->{'keywords'} = \@keywords;
#    }
#    
#    # Fix up people fields into User objects
#    my @people = ("assigned_to", "reporter", "qa_contact");
#    foreach my $field (@people) {
#        fix_person($cgi, $bug, $field);
#    }
#  
#    # fix_person can't quite cope with this
#    if ($bug->{'cc'}) {
#        for (my $i = 0; $i < scalar(@{$bug->{'cc'}}); $i++) {
#            $bug->{'cc'}->[$i] = { 'name' => $bug->{'cc'}->[$i] };
#            if ($bug->{'cc'}->[$i]->{'name'} =~ /@/) {
#                $bug->{'cc'}->[$i]->{'ref'} = 
#                    $cgi->uri_for("/user", $bug->{'cc'}->[$i]->{"name"})->as_string;
#            }
#        }
#    }
#  
#    fix_time($cgi, $bug, "creation_time");
#    fix_time($cgi, $bug, "last_change_time");
#    
#    $bug->{'ref'} = $cgi->uri_for("/bug", $bug->{'id'})->as_string;
#  
#    # Bugzilla fields we always want to be in the returned data. These two
#    # are a bit special because 1 is the default, and therefore it's worth 
#    # explicitly flagging it up (groan) if they are set to 0.
#    my %everpresent = (
#        "is_cc_accessible"       => "0",
#        "is_reporter_accessible" => "0",
#    );
#    
#    foreach my $field (keys %everpresent) {
#        if (!defined($bug->{$field})) {
#            $bug->{$field} = $everpresent{$field};
#        }
#    }
#    
#    # This only appears on the query interface, and it's calculable from other
#    # fields anyway, so we don't support it for the moment.
#    delete($bug->{'percentage_complete'});
#    
#    delete($bug->{'votes'});
#    
#    return $bug;
#}
#
## Used for bug object resulting from parsing XML from legacy XML interface.
#sub fixup_xml_bug {
#    my ($cgi, $bug) = @_;
#    
#    $bug = fixup_bug($cgi, $bug);
#    
#    # We don't supply product or component IDs, so we don't need this one either
#    delete $bug->{'classification_id'};
#    
#    # Attachment times and references
#    if ($bug->{'attachments'}) {
#        foreach my $attachment (@{$bug->{'attachments'}}) {
#            $attachment->{'ref'} = $cgi->uri_for("/attachment", 
#                                   $attachment->{'attachid'})->as_string;
#  
#            # Change some field names
#            foreach my $field (grep(/^attachments/, keys %{$OLD2NEW})) {
#                $field =~ /^attachments\.(.*)$/;
#                my $oldfieldname = $1;
#                $OLD2NEW->{$field} =~ /^attachment\.(.*)$/;
#                change_field_name($attachment, $oldfieldname, $1);
#            }
#  
#            fix_person($cgi, $attachment, "attacher");
#  
#            fix_flag_people($cgi, $attachment);
#        
#            fix_time($cgi, $attachment, "creation_time");
#            fix_time($cgi, $attachment, "last_change_time");
#    
#            $attachment->{'bug_ref'} = $cgi->uri_for("/bug", $bug->{'id'})->as_string;
#            $attachment->{'bug_id'} = $bug->{'id'};
#        
#            if ($attachment->{'data'}) {
#                # XML 'helpfully' inserts newlines
#                $attachment->{'data'}->{'content'} =~ s/\n//g;
#                # Flatten out attachment data
#                $attachment->{'encoding'} = $attachment->{'data'}->{'encoding'};
#                $attachment->{'data'} = $attachment->{'data'}->{'content'};
#            }
#        }
#    }
#  
#    fix_flag_people($cgi, $bug);
#  
#    if ($bug->{'groups'}) {
#        foreach my $group (@{$bug->{'groups'}}) {
#            change_field_name($group, 'content', 'name');
#        }
#    }
#  
#    # Change field names on comments, and rearrange structure,
#    # moving across to new name at the same time
#    if ($bug->{'long_desc'}) {
#        # First promote, to make loop easier
#        if (ref $bug->{'long_desc'} ne "ARRAY") {
#            $bug->{'long_desc'} = [ $bug->{'long_desc'} ];
#        }
#      
#        $bug->{'comments'} = [];
#        for (my $i = 0; $i < @{$bug->{'long_desc'}}; $i++) {
#            my $long_desc = $bug->{'long_desc'}->[$i];
#            fix_person($cgi, $long_desc, 'who');
#            my $comment = {
#                'creation_time' => $long_desc->{'bug_when'},
#                'is_private' => $long_desc->{'isprivate'},
#                'text' => $long_desc->{'thetext'},
#                'author' => $long_desc->{'who'},
#                'id' => $long_desc->{'commentid'}
#            };
#        
#            push(@{$bug->{'comments'}}, $comment);
#        }
#      
#        delete $bug->{'long_desc'};
#    }
#    
#    # Add bug references
#    fix_comments($cgi, $bug);
#    
#    return $bug;
#}
#
## There are lots of ways a "person" can be the wrong shape; sort them all out
## This sub shouldn't have any effect if the shape is right.
#sub fix_person {
#    my ($cgi, $bug, $field) = @_;
#    
#    if ($bug->{$field . "_realname"}) {
#        # Two fields version
#        $bug->{$field} = { 'name' => $bug->{$field} };
#        $bug->{$field}->{"real_name"} = $bug->{$field . '_realname'};      
#        delete($bug->{$field . '_realname'});
#    }
#    elsif (ref($bug->{$field}) && $bug->{$field}->{'content'}) {
#        # Wrong field names version
#        $bug->{$field}->{"real_name"} = $bug->{$field}->{'name'};
#        $bug->{$field}->{"name"} = $bug->{$field}->{'content'};
#        delete $bug->{$field}->{'content'};
#    }
#    elsif (!ref($bug->{$field})) {
#        # Plain string - assume it's a name
#        $bug->{$field} = { 'name' => $bug->{$field} };
#    }
#  
#    if (ref $bug->{$field} && $bug->{$field}->{"name"}) {
#        # "ref" fields only when logged in
#        if ($bug->{$field}->{"name"} =~ /@/) {
#            # XXX Provide numeric instead?
#            my $ref = $cgi->uri_for("/user", $bug->{$field}->{"name"})->as_string;
#            $bug->{$field}->{"ref"} = $ref;
#        }
#    }
#}
#
#sub fix_flag_people {
#    my ($cgi, $thing) = @_;
#    
#    if ($thing->{'flags'}) {
#        foreach my $flag (@{$thing->{'flags'}}) {
#            fix_person($cgi, $flag, 'setter');
#            if ($flag->{'requestee'}) {
#                fix_person($cgi, $flag, 'requestee');
#            }
#        }
#    }
#}
#
#sub fix_comments {
#    my ($cgi, $bug) = @_;
#    
#    if ($bug->{'comments'}) {
#        foreach my $comment (@{$bug->{'comments'}}) {
#            # Promote author to user object
#            fix_person($cgi, $comment, 'author');
#        
#            delete($comment->{'bug_id'});
#            change_field_name($comment, 'time', 'creation_time');
#            fix_time($cgi, $comment, "creation_time");      
#        }
#    }
#}
#
#sub fix_time {
#    my ($cgi, $object, $field) = @_;
#    my $orig = $object->{$field};
#    my $time;
#    
#    # Cope with new XML time format with local_time attribute
#    if (ref $orig) {
#        $orig = $orig->{'local_time'};
#    }
#    
#    if ($orig =~ / [+-]\d{4}$/) {
#        # If time has timezone, we trust it
#        $time = str2time($orig);
#    }
#    else {
#        # Use timezone specified in config file
#        $time = str2time($orig, Bugzilla->local_timezone);    
#    }
#  
#    if ($time) {
#        my $dt = DateTime->from_epoch(epoch => $time);
#        $object->{$field} = $dt->strftime("%Y-%m-%dT%TZ");
#    }
#    else {
#        # There isn't a great way of signalling an error... and at least this
#        # will help with debugging.
#        $object->{$field} = "$orig (str2time failed)";
#    }
#}
#
#sub unfix_time {
#    my ($cgi, $bug, $field) = @_;
#    my $time = str2time($bug->{$field}, "UTC");    
#    my $dt = DateTime->from_epoch(epoch => $time, 
#                                  time_zone => Bugzilla->local_timezone);
#    $bug->{$field} = $dt->strftime("%Y-%m-%d %T");
#}
#
#sub flags2hash {
#    my ($newobj, $hash) = @_;
#    
#    foreach my $flag (@{$newobj->{'flags'}}) {
#        if ($flag->{'id'}) {
#            # Existing flag
#            my $id = $flag->{'id'};
#            $hash->{"flag-" . $id} = $flag->{'status'};
#            if ($flag->{'requestee'}) {
#                $hash->{"requestee-" . $id} = $flag->{'requestee'}->{'name'};
#            }
#        }
#        else {
#            # New flag
#            # Note: multiplicable flags can only be added one at a time. If you 
#            # try and set one more than once, results are undefined. (cop-out...)
#            my $id = $flag->{'type_id'};
#            $hash->{"flag_type-" . $id} = $flag->{'status'};
#            if ($flag->{'requestee'}) {
#                $hash->{"requestee_type-" . $id} = $flag->{'requestee'}->{'name'};
#            }
#        }
#    }
#}
#
## This is sort of an un-blessing
#sub xmlrpc_error2error {
#    return { 
#        'error'   => 1,
#        'message' => $_[0]->{'message'},
#        'code'    => $_[0]->{'xmlrpc_code'} 
#    };
#}
#
## Errors returned on the show_bug.cgi XML ctype
#sub xml_error2error {
#    my ($xmlerror) = @_;
#    my $error = {
#        'message' => $xmlerror->{'error'}, 
#        'error' => 1
#    };
#    
#    # Yes, InvalidBugId => Invalid Alias, and NotFound => Invalid Bug ID.
#    if ($xmlerror->{'error'} eq "InvalidBugId") {
#        $error->{'message'} = "Invalid Bug Alias";
#        $error->{'code'} = 100;
#    }
#    elsif ($xmlerror->{'error'} eq "NotFound") {
#        $error->{'message'} = "Invalid Bug ID";
#        $error->{'code'} = 101;
#    }
#    elsif ($xmlerror->{'error'} eq "NotPermitted") {
#        $error->{'message'} = "Access Denied";
#        $error->{'code'} = 102;
#    }
#    
#    return $error;
#}
#
#sub http_result2error {
#    my ($res) = @_;
#    
#    if (!$res->is_success) {
#        return { 'error' => 1, 
#                 'message' => "HTTP Error: " . $res->status_line,
#                 'http_code' => $res->code
#        };
#    }
#    else {
#        # HTTP code is success, but there is still an error. Parse the HTML
#        # page to find out what
#        my $error = { 'error' => 1 };
#        my $message;
#        my $code;
#      
#        $res->decoded_content =~ /<title>(.*)<\/title>/s;
#        my $title = $1;
#        if (!$title) {
#            # Software error?
#            $res->decoded_content =~ /<h1>(.*)<\/h1>/s;
#            $title = $1 || "";
#            if ($title eq "Software error:") {
#                $res->decoded_content =~ /<pre>(.*)<\/pre>/s;
#                $message = $title . " " . $1;
#            }
#            else {
#                $message = "Unknown titleless error";
#            }
#        }
#        elsif ($title eq "Unknown Keyword") {
#            $message = $title;
#            $code = 104; # XXX is this right? more specific code?
#        }
#        elsif ($title eq "Alias In Use") {
#            $message = $title;
#            $code = 103; # XXX asking Max
#        }
#        elsif ($title eq "Mid-air collision!") {
#            $message = "Mid-air collision";
#            $res->request->uri =~ /delta_ts=([^&]+)/s;
#            my $sltc = $1 ? uri_unescape($1) : "";
#            $sltc =~ s/\+/ /g;
#            $error->{'submitted_last_change_time'} = $sltc;
#            $res->decoded_content =~ /name="delta_ts"\s+value="([^"]+)"/s;
#            $error->{'actual_last_change_time'} = $1 || "";
#        }
#        elsif ($title eq "Internal Error") {
#            $message = $title;
#            if ($res->decoded_content =~ 
#                                 /\Q<font size="+2">\E\s*(.*?)\s*\Q<\/font>\E/s) 
#            {
#                $message .= ": " . $1;
#            }
#        }
#        elsif ($res->decoded_content =~ /with an invalid/ ||
#               $res->decoded_content =~ /Token Does Not Exist/) 
#        {
#            $message = "Bad token";
#            $code = 108; # XXX more specific?
#        }
#        elsif ($res->decoded_content =~ /legitimate login/) {
#            $message = "Not logged in";
#        }
#        elsif ($res->decoded_content =~ /Verify New Product/) {
#            $message = "Product change - API user shouldn't get this";
#            $code = -32000;
#        }
#        elsif ($res->decoded_content =~ /There is no component/) {
#            $message = "Invalid component";
#            $code = 105;
#        }
#        elsif ($res->decoded_content =~ /Invalid Username/) {
#            $message = "Invalid username or password";
#            $code = 300;
#        }
#        else {
#            $message = "Unknown Bugzilla error. Title: '$1'";
#            $error->{'html_page'} = $res->decoded_content;
#        }
#      
#        $error->{'message'} = $message;
#        $error->{'code'} = $code || 32000;
#      
#        return($error);
#    }      
#}
#
#sub downgrade_search_url {
#    my ($cgi, $url) = @_;
#  
#    my @delete = qw(include_fields exclude_fields username password 
#                    attachmentdata);
#    foreach my $param (@delete) {
#        $url->query_param_delete($param);
#    }
#  
#    # Default search types because the normal query form does this and it
#    # seems polite
#    my @textfields = ("comment", "keywords", "summary", "url", "whiteboard");
#    foreach my $field (@textfields) {
#        if ($url->query_param($field) &&
#            !$url->query_param($field . "_type"))
#        {
#            my $default = $field eq "keywords" ? "contains_all_words" : 
#                                                 "contains_all";
#            $url->query_param($field . "_type", $default);
#        }
#    }
#
#    # Special value for changed_field; can't use $NEW2OLD because that maps
#    # to something different for another reason.
#    if (defined($url->query_param('changed_field')) && 
#        $url->query_param('changed_field') eq "creation_time") 
#    {
#        $url->query_param('changed_field', "[Bug creation]");
#    }
#
#    # Update values of various forms. 
#    foreach my $key ($url->query_param()) {
#        # First, search types. These are found in the value of any field ending 
#        # _type, and the value of any field matching type\d-\d-\d.
#        if ($key =~ /^type(\d+)-(\d+)-(\d+)$|_type$/) {
#            $url->query_param($key, map { $NEWTYPES2OLD->{$_} || $_ } $url->query_param($key));
#        }
#    
#        # Field names hiding in values instead of keys: changed_field, Boolean
#        # Charts and axis names.
#        if ($key =~ /^(field\d+-\d+-\d+|
#                      changed_field|
#                      (x|y|z)_axis_field)$
#                    /x) {
#        $url->query_param($key, 
#                           map { $NEW2OLD->{$_} || $_ } $url->query_param($key));
#        }
#    }                       
#
#    # Update field names
#    foreach my $field (keys %$NEW2OLD) {
#        change_query_param_name($url, $field, $NEW2OLD->{$field});
#    }
#  
#    # Time field names are screwy, and got reused. We can't put this mapping
#    # in NEW2OLD as everything will go haywire. actual_time has to be queried
#    # as work_time even though work_time is the submit-only field for _adding_
#    # to actual_time, which can't be arbitrarily manipulated.
#    change_query_param_name($url, 'actual_time', 'work_time');  
#}

#sub exclude_fields {
#    my ($params, $thing) = @_;
#  
#    # If $obj is not an array, promote it to one so following code can be
#    # generic
#    if (ref $thing ne "ARRAY") {
#        $thing = [$thing];
#    }
#  
#    # Exclude fields
#    my @exclude_fields = split(/\s*,\s*/, $params->{'exclude_fields'} || "");
#
#    foreach my $obj (@$thing) {
#        foreach my $field (@exclude_fields) {
#            delete $obj->{$field};
#        }
#    }
#}
#
#sub get_include_fields {
#    my ($params) = @_;
#  
#    my @include_fields = split(/\s*,\s*/, $params->{'include_fields'} || "");
#    my %include_fields = map { $_ => 1 } @include_fields;
#  
#    return \%include_fields;  
#}

# $result is both an in and out parameter - the thing it points to gets
# modified.
#
# This sub only works for places where _default == _all, or the fields which
# make up the difference are known, enumerated and passed in as an arrayref.
sub adjust_fields {
    my ($params, $result, $differences) = @_;
    
    # $result can be undef (e.g. if there was an error)
    return if !$result;
    
    my @include_fields = ref $params->{'include_fields'} 
                         ? @{ $params->{'include_fields'} }
                         : split(/\s*,\s*/, $params->{'include_fields'} || "");
    my %include_fields = map { $_ => 1 } @include_fields;

    my @exclude_fields = ref $params->{'exclude_fields'}
                         ? @{ $params->{'exclude_fields'} }
                         : split(/\s*,\s*/, $params->{'exclude_fields'} || "");
    
    # For the moment, we assume _default == _all...
    my $all = !@include_fields || $include_fields{"_all"} || 
              $include_fields{"_default"} || 0;
    
    # But now, if we are _defaulting, and _default != _all, we need to 
    # _exclude_ any field in the set which makes the difference between 
    # _default and _all and which is not explicitly _included_.
    if ($include_fields{"_default"} && $differences) {
        foreach my $field (@$differences) {
            if (!$include_fields{$field}) {
                push(@exclude_fields, $field);
            }
        }
    }
  
    if (!$all) {
        # Remove everything that's not an include_field
        foreach my $key (keys %$result) {
            if (!$include_fields{$key}) {
                delete $result->{$key};
            }
        }
    }
      
    # Remove exclude_fields
    foreach my $exclude (@exclude_fields) {
        delete $result->{$exclude};
    }

    return $result;
}

1;
