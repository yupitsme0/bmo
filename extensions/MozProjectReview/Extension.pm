# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.
package Bugzilla::Extension::MozProjectReview;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::Constants;

our $VERSION = '0.01';

sub post_bug_after_creation {
    my ($self, $args) = @_;
    my $vars = $args->{vars};
    my $bug = $vars->{bug};

    if (Bugzilla->input_params->{format}
        && Bugzilla->input_params->{format} eq 'moz-project-review'
        && $bug->component eq '')
    {
        my $error_mode_cache = Bugzilla->error_mode;
        Bugzilla->error_mode(ERROR_MODE_DIE);

        my $template = Bugzilla->template;
        my $cgi = Bugzilla->cgi;

        my ($investigate_bug, $ssh_key_bug);
        my $old_user = Bugzilla->user;
        eval {
            Bugzilla->set_user(Bugzilla::User->new({ name => 'nobody@mozilla.org' }));
            my $new_user = Bugzilla->user;

            # HACK: User needs to be in the editbugs and primary bug's group to allow
            # setting of dependencies.
            $new_user->{'groups'} = [ Bugzilla::Group->new({ name => 'editbugs' }), 
                                      Bugzilla::Group->new({ name => 'infra' }), 
                                      Bugzilla::Group->new({ name => 'infrasec' }) ];

            my $recipients = { changer => $new_user };
            $vars->{original_reporter} = $old_user;

            my $comment;
            $cgi->param('display_action', '');
            $template->process('bug/create/comment-employee-incident.txt.tmpl', $vars, \$comment)
                || ThrowTemplateError($template->error());

            $investigate_bug = Bugzilla::Bug->create({ 
                short_desc        => 'Investigate Lost Device',
                product           => 'mozilla.org',
                component         => 'Security Assurance: Incident',
                status_whiteboard => '[infrasec:incident]',
                bug_severity      => 'critical',
                cc                => [ 'mcoates@mozilla.com', 'jstevensen@mozilla.com' ],
                groups            => [ 'infrasec' ], 
                comment           => $comment,
                op_sys            => 'All', 
                rep_platform      => 'All',
                version           => 'other',
                dependson         => $bug->bug_id, 
            });
            $bug->set_all({ blocked => { add => [ $investigate_bug->bug_id ] }});
            Bugzilla::BugMail::Send($investigate_bug->id, $recipients);

            Bugzilla->set_user($old_user);
            $vars->{original_reporter} = '';
            $comment = '';
            $cgi->param('display_action', 'ssh');
            $template->process('bug/create/comment-moz-project-review.txt.tmpl', $vars, \$comment)
                || ThrowTemplateError($template->error());

            $ssh_key_bug = Bugzilla::Bug->create({ 
                short_desc        => 'Disable/Regenerate SSH Key',
                product           => $bug->product,
                component         => $bug->component,
                bug_severity      => 'critical',
                cc                => $bug->cc,
                groups            => [ map { $_->{name} } @{ $bug->groups } ],
                comment           => $comment,
                op_sys            => 'All', 
                rep_platform      => 'All',
                version           => 'other',
                dependson         => $bug->bug_id, 
            });
            $bug->set_all({ blocked => { add => [ $ssh_key_bug->bug_id ] }});
            Bugzilla::BugMail::Send($ssh_key_bug->id, $recipients);
        };
        my $error = $@;

        Bugzilla->set_user($old_user);
        Bugzilla->error_mode($error_mode_cache);

        if ($error || !$investigate_bug || !$ssh_key_bug) {
            warn "Failed to create additional moz-project-review bug: $error" if $error;
            $vars->{'message'} = 'moz_project_review_creation_failed';
        }
    }
}

__PACKAGE__->NAME;
