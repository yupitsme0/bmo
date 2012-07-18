#!/usr/bin/perl -w

use strict;
use warnings;
$| = 1;

use constant ROLLBACK => 0;
use lib qw(. lib);

use constant SKIP_PRODUCTS => (
    'Bugzilla',
);

use Cwd 'abs_path';
use File::Basename;
use POSIX 'strftime';

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Field;
use Bugzilla::Install::Util qw(indicate_progress);
use Bugzilla::Util;

use constant REL_COMPONENT_WATCHER => 15;

Bugzilla->usage_mode(USAGE_MODE_CMDLINE);
confirmation() unless ROLLBACK;

my $dbh = Bugzilla->dbh;
my %watch_users;
my $watch_users_list;

my ($nobody_user_id) = $dbh->selectrow_array("
    SELECT userid
      FROM profiles
     WHERE login_name = 'nobody\@mozilla.org'"
);

#

$dbh->bz_start_transaction();
eval {

    sanity_check();
    read_watch_users();
    update_bugs();
    copy_email_settings();
    reset_qa();

    die "bailing out" if ROLLBACK;

    print ts()."Committing transaction...\n";
    $dbh->bz_commit_transaction();
    print ts()."Done.\n";
};
if ($@) {
    print ts()."Rolling back transaction...\n";
    $dbh->bz_rollback_transaction();
    print ts()."$@\n";
}

#

sub sanity_check {
    print ts()."Checking schema...\n";
    # make sure bug 684701 has been deployed
    if (!$dbh->bz_column_info('components', 'watch_user')) {
        die "Failed to find column components.watch_user\n";
    }
    # make sure the migration script from bug 684701 has been executed
    if (!$dbh->selectrow_array("
        SELECT 1
          FROM components
         WHERE watch_user IS NOT NULL"
    )) {
        die "Failed to find any component watch-users:\n".
            "extensions/ComponentWatching/migrate_qa_to_component_watch.pl has not been run.\n";
    }
}

sub confirmation {
    print "This script will perform a one-time migration of QA watchers.\n";
    print "See Bug 684088 for details\n\n";
    print "Press <Ctrl-C> to stop or <Enter> to continue...\n";
    getc();
}

sub read_watch_users {
    print ts()."Reading watch-users...\n";

    # build up the list of components the watch-users are bound to
    my $sth;
    if (SKIP_PRODUCTS) {
        my $product_list = join(',', map { $dbh->quote($_) } SKIP_PRODUCTS);
        $sth = $dbh->prepare("
            SELECT watch_user, product_id, components.id, profiles.login_name
              FROM components
                   INNER JOIN profiles ON profiles.userid = components.watch_user
                   INNER JOIN products ON products.id = components.product_id
             WHERE watch_user IS NOT NULL
                   AND (NOT products.name IN ($product_list))
        ");
    } else {
        $sth = $dbh->prepare("
            SELECT watch_user, product_id, components.id, profiles.login_name
              FROM components
                   INNER JOIN profiles ON profiles.userid = components.watch_user
             WHERE watch_user IS NOT NULL
        ");
    }
    $sth->execute;
    while (my($user_id, $product_id, $component_id, $login_name) = $sth->fetchrow_array) {
        if (!$watch_users{$user_id}) {
            $watch_users{$user_id}{login} = $login_name;
            $watch_users{$user_id}{watch} = [];
        }
        push @{$watch_users{$user_id}{watch}}, [$product_id, $component_id];
    }
    $watch_users_list = join(',', keys %watch_users);

    printf ts()."Found %s watch-users...\n", scalar keys %watch_users;
}

sub update_bugs {
    print ts()."Reading bugs...\n";

    # init
    my $qa_field_id = get_field_id('qa_contact');

    my $ra_bugs = $dbh->selectall_arrayref("
        SELECT bug_id, qa_contact
          FROM bugs
         WHERE qa_contact IN ($watch_users_list)"
    );

    my $bug_count = scalar @$ra_bugs;
    unless ($bug_count) {
        print ts()."No bugs require updating.\n";
        die "Migration has already been executed.\n";
    }
    print ts()."Updating $bug_count bugs...\n";
    my $now = $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    for (my $i = 0; $i < $bug_count; $i++) {
        indicate_progress({ current => $i + 1, total => $bug_count, every => 1000 });
        my ($bug_id, $old_qa_id) = @{$ra_bugs->[$i]};
        # update the bug
        $dbh->do("
            UPDATE bugs 
               SET qa_contact = NULL, delta_ts = ?, lastdiffed = ?
             WHERE bug_id = ?",
            undef,
            $now, $now, $bug_id
        );
        # insert into bug activity
        $dbh->do("
            INSERT INTO bugs_activity(bug_id, who, bug_when, fieldid, removed, added)
                 VALUES (?, ?, ?, ?, ?, ?)",
            undef,
            $bug_id, $nobody_user_id, $now, $qa_field_id, _login($old_qa_id), ''
        );
    }
}

sub copy_email_settings {
    print ts()."Reading watchers...\n";

    # get list of users watching watch-users
    my $ra_watches = $dbh->selectall_arrayref("
        SELECT watcher, watched
          FROM watch
         WHERE watched IN ($watch_users_list)
      ORDER BY watcher"
    );

    my $watch_count = scalar @$ra_watches;
    unless ($watch_count) {
        print ts()."No watchers require updating.\n";
        return;
    }
    print ts()."Migrating $watch_count watchers...\n";
    my %component_watch;

    # copy email settings to component watching
    my %watches_user_ids;
    foreach my $ra (@$ra_watches) {
        $watches_user_ids{$ra->[0]} = 1;
    }
    print ts()."Migrating email settings for " . (scalar keys %watches_user_ids) . " users...\n";
    foreach my $user_id (sort { $a <=> $b } keys %watches_user_ids) {
        # don't copy rel_qa to rel_component_watcher if there are existing
        # rel_component_watcher settings
        my ($has_component_settings) = $dbh->selectrow_array("
            SELECT COUNT(*) 
              FROM email_setting
             WHERE user_id=?
                   AND relationship=?",
            undef,
            $user_id, REL_COMPONENT_WATCHER
        );
        next if $has_component_settings;

        my $ra_qa_settings = $dbh->selectcol_arrayref("
            SELECT event
              FROM email_setting
             WHERE user_id=?
                   AND relationship=?",
            undef,
            $user_id, REL_QA
        );
        foreach my $event (@$ra_qa_settings) {
            $dbh->do("
                INSERT INTO email_setting(user_id, relationship, event)
                     VALUES (?, ?, ?)",
                undef,
                $user_id, REL_COMPONENT_WATCHER, $event
            );
        }
    }

}

sub reset_qa {
    # set component.qa to nothing
    print ts()."Updating components...\n";
    $dbh->do("
        UPDATE components
           SET initialqacontact=NULL
         WHERE initialqacontact IN ($watch_users_list)");
}

#

sub same_array_content {
    my ($ra_a, $ra_b) = @_;
    return 0 if scalar @$ra_a != scalar @$ra_b;
    foreach my $a (@$ra_a) {
        return 0 unless grep { $_ eq $a } @$ra_b;
    }
    return 1;
}

sub ts {
    return strftime "[%H:%M:%S] ", localtime;
}

# debugging methods

my %cache;

sub _login {
    my $id = shift;
    $cache{login}{$id} ||=
        lc $dbh->selectrow_array("SELECT login_name FROM profiles WHERE userid=?", undef, $id);
    return $cache{login}{$id};
}

sub _prod {
    my $id = shift;
    $cache{prod}{$id} ||=
        $dbh->selectrow_array("SELECT name FROM products WHERE id=?", undef, $id);
    return $cache{prod}{$id};
}

sub _comp {
    my $id = shift;
    $cache{comp}{$id} ||=
        $dbh->selectrow_array("SELECT name FROM components WHERE id=?", undef, $id);
    return $cache{comp}{$id};
}

