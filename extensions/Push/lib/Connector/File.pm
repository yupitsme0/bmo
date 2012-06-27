# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::Push::Connector::File;

use strict;
use warnings;

use base 'Bugzilla::Extension::Push::Connector::Base';

use Bugzilla::Constants;
use Bugzilla::Extension::Push::Constants;
use Encode;
use FileHandle;
use JSON;

sub init {
    my ($self) = @_;
    $self->{json} = JSON->new();
    $self->{json}->shrink(1);
    $self->{json}->canonical(1);
}

sub options {
    return (
        {
            name     => 'filename',
            label    => 'Filename',
            type     => 'string',
            default  => 'push.log',
            required => 1,
            validate => sub {
                my $filename = shift;
                $filename =~ m#^/#
                    && die "Absolute paths are not permitted\n";
            },
        },
    );
}

sub should_send {
    my ($self, $message) = @_;
    return 1;
}

sub send {
    my ($self, $message) = @_;
    my $json = $self->{json};

    # pretty-format json payload
    my $payload = $message->payload;
    if (utf8::is_utf8($payload)) {
        $payload = encode('utf8', $payload);
    }
    my $rh = from_json($payload);
    $payload = $json->pretty->encode($rh);

    my $filename = bz_locations()->{'datadir'} . '/' . $self->config->{filename};
    Bugzilla->push_ext->logger->debug("File: Appending to $filename");
    my $fh = FileHandle->new(">>$filename");
    $fh->binmode(':utf8');
    $fh->print(
        "[" . scalar(localtime) . "]\n" .
        $payload . "\n\n"
    );
    $fh->close;

    return PUSH_RESULT_OK;
}

1;

