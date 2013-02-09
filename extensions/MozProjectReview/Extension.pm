# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.
package Bugzilla::Extension::MozProjectReview;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::User;
use Bugzilla::Group;
use Bugzilla::Error;
use Bugzilla::Constants;

our $VERSION = '0.01';

sub post_bug_after_creation {
    my ($self, $args) = @_;
    my $vars   = $args->{vars};
    my $bug    = $vars->{bug};

    my $user     = Bugzilla->user;
    my $params   = Bugzilla->input_params;
    my $template = Bugzilla->template;

    return if !($params->{format}
                && $params->{format} eq 'moz-project-review'
                && $bug->component eq 'Project Review');

    my $error_mode_cache = Bugzilla->error_mode;
    Bugzilla->error_mode(ERROR_MODE_DIE);

    # do a match if applicable
    Bugzilla::User::match_field({
        'legal_cc' => { 'type' => 'multi' }
    });

    my ($do_sec_review, $do_legal, $do_finance, $do_privacy_vendor,
        $do_data_safety, $do_privacy_tech, $do_privacy_policy);

    if ($params->{mozilla_data} eq 'Yes') {
        $do_legal = 1;
        $do_privacy_policy = 1;
        $do_privacy_tech = 1;
        $do_sec_review = 1;
    }

    if ($params->{mozilla_data} eq 'Yes'
        && $params->{data_safety_user_data} eq 'Yes')
    {
        $do_data_safety = 1;
    }

    if ($params->{new_or_change} eq 'New') {
        $do_legal = 1;
        $do_privacy_policy = 1;
    }
    elsif ($params->{new_or_change} eq 'Existing') {
        $do_legal = 1;
    }

    if ($params->{separate_party} eq 'Yes'
        && $params->{relationship_type} ne 'Hardware Purchase') {
        $do_legal = 1;
    }

    if ($params->{data_access} eq 'Yes') {
        $do_privacy_policy = 1;
        $do_sec_review = 1;
    }

    if ($params->{data_access} eq 'Yes'
        && $params->{'privacy_policy_vendor_user_data'} eq 'Yes') 
    {
        $do_privacy_vendor = 1;
    }

    if ($params->{vendor_cost} eq '> $25,000' 
        || ($params->{vendor_cost} eq '<= $25,000'
            && $params->{po_needed} eq 'Yes')) 
    {
        $do_finance = 1;
    }

    my ($sec_review_bug, $legal_bug, $finance_bug, $privacy_vendor_bug,
        $data_safety_bug, $privacy_tech_bug, $privacy_policy_bug, $error, 
        @dep_bug_comment, @dep_bug_errors);

    if ($do_sec_review) {
        my $bug_data = {
            short_desc   => 'Security Review for ' . $bug->short_desc,
            product      => 'mozilla.org',
            component    => 'Security Assurance: Review Request',
            bug_severity => 'normal',
            groups       => [ 'mozilla-corporation-confidential' ],
            keywords     => 'sec-review-needed',
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'other',
            blocked      => $bug->bug_id,
        };
        ($sec_review_bug, $error) = _file_child_bug($bug, $vars, 'sec-review', $bug_data);
        if (!$error && $sec_review_bug) {
            push(@dep_bug_comment, "Bug " . $sec_review_bug->id . " - " . $sec_review_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Security Review bug");
            push(@dep_bug_errors, "Security Review: $error");
            $error = undef;
        }
    }

    if ($do_legal) {
        my $component;
        if ($params->{new_or_change} eq 'New') {
            $component = 'General';
        }
        elsif ($params->{new_or_change} eq 'Existing') {
            $component = $params->{mozilla_project};
        }

        if ($params->{separate_party} eq 'Yes'
            && $params->{relationship_type}) 
        {
            $component = $params->{relationship_type} eq 'unspecified'
                       ? 'General'
                       : $params->{relationship_type};
        }

        my $bug_data = {
            short_desc   => 'Complete Legal Review for ' . $bug->short_desc,
            product      => 'Legal', 
            component    => $component,
            bug_severity => 'normal',
            priority     => '--',
            groups       => [ 'legal' ],
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'unspecified',
            blocked      => $bug->bug_id,
            cc           => $params->{'legal_cc'},
        };
        ($legal_bug, $error) = _file_child_bug($bug, $vars, 'legal', $bug_data);
        if (!$error && $legal_bug) {
            push(@dep_bug_comment, "Bug " . $legal_bug->id . " - " . $legal_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Legal Review bug");
            push(@dep_bug_errors, "Legal Review: $error");
            $error = undef;
        }
    }

    if ($do_finance) {
        my $bug_data = {
            short_desc   => 'Complete Finance Review for ' . $bug->short_desc,
            product      => 'Finance',
            component    => 'Purchase Request Form',
            bug_severity => 'normal',
            priority     => '--',
            groups       => [ 'finance' ],
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'unspecified',
            blocked      => $bug->bug_id,
        };
        ($finance_bug, $error) = _file_child_bug($bug, $vars, 'finance', $bug_data);
        if (!$error && $finance_bug) {
            push(@dep_bug_comment, "Bug " . $finance_bug->id . " - " . $finance_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Finance Review bug");
            push(@dep_bug_errors, "Finance Review: $error");
            $error = undef;
        }
    }

    if ($do_data_safety) {
        my $bug_data = {
            short_desc   => 'Data Safety Review for ' . $bug->short_desc,
            product      => 'Data Safety',
            component    => 'General',
            bug_severity => 'normal',
            priority     => '--',
            groups       => [ 'mozilla-corporation-confidential' ],
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'unspecified',
            blocked      => $bug->bug_id,
        };
        ($data_safety_bug , $error) = _file_child_bug($bug, $vars, 'data-safety', $bug_data);
        if (!$error && $data_safety_bug) {
            push(@dep_bug_comment, "Bug " . $data_safety_bug->id . " - " . $data_safety_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Data Safety Review bug");
            push(@dep_bug_errors, "Data Safety Review: $error");
            $error = undef;
        }        
    }

    if ($do_privacy_tech) {
        my $bug_data = {
            short_desc   => 'Complete Privacy-Technical Review for ' . $bug->short_desc,
            product      => 'mozilla.org',
            component    => 'Security Assurance: Review Request',
            bug_severity => 'normal',
            priority     => '--',
            keywords     => 'privacy-review-needed',
            groups       => [ 'mozilla-corporation-confidential' ],
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'other',
            blocked      => $bug->bug_id,
        };
        ($privacy_tech_bug, $error) = _file_child_bug($bug, $vars, 'privacy-tech', $bug_data);
        if (!$error && $privacy_tech_bug) {
            push(@dep_bug_comment, "Bug " . $privacy_tech_bug->id . " - " . $privacy_tech_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Privacy-Technical Review bug");
            push(@dep_bug_errors, "Privacy-Technical Review: $error");
            $error = undef;
        }        
    }

    if ($do_privacy_policy) {
        my $bug_data = {
            short_desc   => 'Complete Privacy-Policy Review for ' . $bug->short_desc,
            product      => 'Privacy',
            component    => 'Privacy Review',
            bug_severity => 'normal',
            priority     => '--',
            groups       => [ 'mozilla-corporation-confidential' ],
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'unspecified',
            blocked      => $bug->bug_id,
        };
        ($privacy_policy_bug, $error) = _file_child_bug($bug, $vars, 'privacy-policy', $bug_data);
        if (!$error && $privacy_policy_bug) {
            push(@dep_bug_comment, "Bug " . $privacy_policy_bug->id . " - " . $privacy_policy_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Privacy Policy Review bug");
            push(@dep_bug_errors, "Privacy-Policy Review: $error");
            $error = undef;
        }
    }

    if ($do_privacy_vendor) {
        my $bug_data = {
            short_desc   => 'Complete Privacy / Vendor Review for ' . $bug->short_desc,
            product      => 'Privacy',
            component    => 'Vendor Review',
            bug_severity => 'normal',
            priority     => '--',
            groups       => [ 'mozilla-corporation-confidential' ],
            op_sys       => 'All',
            rep_platform => 'All',
            version      => 'unspecified',
            blocked      => $bug->bug_id,
        };
        ($privacy_vendor_bug, $error) = _file_child_bug($bug, $vars, 'privacy-vendor', $bug_data);
        if (!$error && $privacy_vendor_bug) {
            push(@dep_bug_comment, "Bug " . $privacy_vendor_bug->id . " - " . $privacy_vendor_bug->short_desc);
        }
        else {
            push(@dep_bug_comment, "Error creating Privacy Vendor Review bug");
            push(@dep_bug_errors, "Privacy Vendor Review: $error");
            $error = undef;
        }
    }

    Bugzilla->error_mode($error_mode_cache);

    if (scalar @dep_bug_errors) {
        warn "[Bug " . $bug->id . "] Failed to create additional moz-project-review bugs:\n" .
             join("\n", @dep_bug_errors);
        $vars->{message} = 'moz_project_review_creation_failed';
    }

    if (scalar @dep_bug_comment) {
        my $comment = join("\n", @dep_bug_comment);
        if (scalar @dep_bug_errors) {
            $comment .= "\n\nSome erors occurred creating dependent bugs and have been recorded";
        }
        $bug->add_comment($comment);
        $bug->update();
    }

    if (scalar @dep_bug_comment) {
        $bug->add_comment(join("\n", @dep_bug_comment));
        $bug->update();
    }
}

sub _file_child_bug {
    my ($parent_bug, $vars, $template_suffix, $bug_data) = @_;
    my $template = Bugzilla->template;
    my ($new_bug, $error);

    eval {
        my $comment;
        my $full_template = "bug/create/comment-moz-project-review-$template_suffix.txt.tmpl";
        $template->process($full_template, $vars, \$comment)
            || ThrowTemplateError($template->error());

        $bug_data->{comment} = $comment;
    
        $new_bug = Bugzilla::Bug->create($bug_data);
        $parent_bug->set_all({ dependson => { add => [ $new_bug->bug_id ] }});
        Bugzilla::BugMail::Send($new_bug->id, { changer => Bugzilla->user });
    };
    $error = $@ if $@;
    
    return ($new_bug, $error);
}

__PACKAGE__->NAME;
