package Bugzilla::Extension::Splinter;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::Extension::Splinter::Util;

use Bugzilla::Template;

our $VERSION = '0.1';

sub bug_format_comment {
    my ($self, $args) = @_;
    
    my $bug = $args->{'bug'};
    my $regexes = $args->{'regexes'};
    my $text = $args->{'text'};
    
    # Add [review] link to the end of "Created attachment" comments
    #
    # We need to work around the way that the hook works, which is intended
    # to avoid overlapping matches, since we *want* an overlapping match
    # here (the normal handling of "Created attachment"), so we add in
    # dummy text and then replace in the regular expression we return from
    # the hook.
    $$text =~ s~((?:^Created\ |\b)attachment\s*\#?\s*(\d+)(\s\[details\])?)
               ~(push(@$regexes, { match => qr/__REVIEW__$2/,
                                   replace => get_review_link($bug, "$2", "[review]") })) &&
                (attachment_id_is_patch($2) ? "$1 __REVIEW__$2" : $1)
               ~egmx;
    
    # And linkify "Review of attachment", this is less of a workaround since
    # there is no issue with overlap; note that there is an assumption that
    # there is only one match in the text we are linkifying, since they all
    # get the same link.
    my $REVIEW_RE = qr/Review\s+of\s+attachment\s+(\d+)\s*:/;
    
    if ($$text =~ $REVIEW_RE) {
        my $review_link = get_review_link($bug, $1, "Review");
        my $attach_link = Bugzilla::Template::get_attachment_link($1, "attachment $1");
    
        push(@$regexes, { match => $REVIEW_RE,
                          replace => "$review_link of $attach_link:"});
    }
}

sub config_add_panels {
    my ($self, $args) = @_;

    my $modules = $args->{panel_modules};
    $modules->{Splinter} = "Bugzilla::Extension::Splinter::Config";
}

sub mailer_before_send {
    my ($self, $args) = @_;
    
    # Post-process bug mail to add review links to bug mail.
    # It would be nice to be able to hook in earlier in the
    # process when the email body is being formatted in the
    # style of the bug-format_comment link for HTML but this
    # is the only hook available as of Bugzilla-3.4.
    add_review_links_to_email($args->{'email'});
}

sub page_before_template {
    my ($self, $args) = @_;
    
    my $REVIEW_RE = qr/Review\s+of\s+attachment\s+(\d+)\s*:/;
    
    my $page_id = $args->{'page_id'};
    my $vars = $args->{'vars'};
    
    if ($page_id eq "splinter.html") {
        # We do this in a way that is safe if the Bugzilla instance doesn't
        # have an attachments.status field (which is a bugzilla.gnome.org
        # addition)
        my $field_object = new Bugzilla::Field({ name => 'attachments.status' });
        my $statuses;
        if ($field_object) {
            $statuses = [map { $_->name } @{ $field_object->legal_values }];
        } else {
            $statuses = [];
        }
        $vars->{'attachment_statuses'} = $statuses;
    }
}

sub webservice {
    my ($self, $args) = @_;
    
    my $dispatch = $args->{dispatch};
    $dispatch->{Splinter} = "Bugzilla::Extension::Splinter::WebService";
}

__PACKAGE__->NAME;
