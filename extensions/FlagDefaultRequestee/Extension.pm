# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::FlagDefaultRequestee;

use strict;
use base qw(Bugzilla::Extension);

our $VERSION = '1';

################
# Installation #
################

sub install_update_db {
    my $dbh = Bugzilla->dbh;
    if (!$dbh->bz_column_info('flagtypes', 'default_requestee')) {
        $dbh->bz_add_column('flagtypes', 'default_requestee', { 
            TYPE => 'INT3', NOTNULL => 0, 
            REFERENCES => { TABLE  => 'profiles', 
                            COLUMN => 'userid', 
                            DELETE => 'SET NULL' }
        });
    }
}

__PACKAGE__->NAME;
