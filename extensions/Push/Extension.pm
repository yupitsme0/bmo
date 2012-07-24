# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::Push;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

our $VERSION = '0';

#
# installation/config hooks
#

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    $args->{'schema'}->{'push'} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            push_ts => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            payload => {
                TYPE => 'LONGTEXT',
                NOTNULL => 1,
            },
            change_set => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            routing_key => {
                TYPE => 'VARCHAR(64)',
                NOTNULL => 1,
            },
        ],
    };
    $args->{'schema'}->{'push_backlog'} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            message_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
            },
            push_ts => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            payload => {
                TYPE => 'LONGTEXT',
                NOTNULL => 1,
            },
            change_set => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            routing_key => {
                TYPE => 'VARCHAR(64)',
                NOTNULL => 1,
            },
            connector => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            attempt_ts => {
                TYPE => 'DATETIME',
            },
            attempts => {
                TYPE => 'INT2',
                NOTNULL => 1,
            },
            last_error => {
                TYPE => 'MEDIUMTEXT',
            },
        ],
        INDEXES => [
            push_backlog_idx => {
                FIELDS => ['message_id', 'connector'],
                TYPE => 'UNIQUE',
            },
        ],
    };
    $args->{'schema'}->{'push_backoff'} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            connector => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            next_attempt_ts => {
                TYPE => 'DATETIME',
            },
            attempts => {
                TYPE => 'INT2',
                NOTNULL => 1,
            },
        ],
        INDEXES => [
            push_backoff_idx => {
                FIELDS => ['connector'],
                TYPE => 'UNIQUE',
            },
        ],
    };
    $args->{'schema'}->{'push_options'} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            connector => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            option_name => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            option_value => {
                TYPE => 'VARCHAR(255)',
                NOTNULL => 1,
            },
        ],
        INDEXES => [
            push_options_idx => {
                FIELDS => ['connector', 'option_name'],
                TYPE => 'UNIQUE',
            },
        ],
    };
    $args->{'schema'}->{'push_log'} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            message_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
            },
            change_set => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            routing_key => {
                TYPE => 'VARCHAR(64)',
                NOTNULL => 1,
            },
            connector => {
                TYPE => 'VARCHAR(32)',
                NOTNULL => 1,
            },
            push_ts => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            processed_ts => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            result => {
                TYPE => 'INT1',
                NOTNULL => 1,
            },
            data => {
                TYPE => 'MEDIUMTEXT',
            },
        ],
    };
}

__PACKAGE__->NAME;
