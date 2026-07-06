#!/usr/bin/perl
# Upload an image as a user's default userpic through the real userpic API
# (allocates a picid, stores the blob with correct dimensions/mimetype/state,
# sets user.defaultpicid) so S2/S1 journal rendering picks it up natively —
# no hardcoded URLs.
#
#   LJHOME=/home/lj perl set-userpic.pl <username> <image-file> [keyword]
use strict;
use lib "$ENV{LJHOME}/cgi-bin";
BEGIN { require "ljlib.pl"; }
use LJ::Userpic;

my ($user, $file, $keyword) = @ARGV;
die "usage: set-userpic.pl <username> <image-file> [keyword]\n" unless $user && $file;

my $u = LJ::load_user($user) or die "no such user: $user\n";

open(my $fh, "<", $file) or die "can't read $file: $!\n";
binmode $fh;
local $/;
my $data = <$fh>;
close $fh;
die "empty image file\n" unless length $data;

local $LJ::THROW_ERRORS = 1;
my $up = eval { LJ::Userpic->create($u, data => \$data) };
die "userpic create failed: $@\n" if $@ || !$up;

# optional keyword mapping (the live default carried none; set if given)
if (defined $keyword && length $keyword) {
    eval { $up->set_keywords($keyword); };
    warn "note: set_keywords failed: $@\n" if $@;
}

$up->make_default;

printf "OK: picid #%d (%dx%d, %s), set as default for %s\n",
    $up->id, $up->width, $up->height, $up->extension, $user;
