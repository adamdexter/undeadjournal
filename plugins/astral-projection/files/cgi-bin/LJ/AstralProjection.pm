#!/usr/bin/perl
#
# LJ::AstralProjection — parallel-publish local entries to the REAL
# deadjournal.com (or any classic LiveJournal-protocol site).
#
# "Write in the crypt; echo into the living world."
#
# How it works: registers on the engine's "postpost" hook, which fires after a
# local entry is successfully saved. If the posting user has Astral Projection
# enabled, the entry is re-posted to the remote site via the LiveJournal flat
# protocol with challenge/response auth.
#
# Safety properties:
#   * The remote password is NEVER stored in plaintext — only its MD5 hex,
#     which is exactly what challenge/response auth needs.
#   * A remote failure can never break the local post (everything is eval'd;
#     the outcome is recorded in the 'astral_last' userprop and shown on
#     /astralprojection.bml).
#   * Bulk-import protection: entries that are backdated, or whose event time
#     is more than 48 hours from "now", are NOT projected. Importing your
#     archive with Astral enabled will not flood the remote site.
#   * Only your own personal-journal posts project (no community posts).
#
package LJ::AstralProjection;

use strict;
use LWP::UserAgent ();
use Digest::MD5 qw(md5_hex);
use Time::Local qw(timelocal);

our $VERSION = "1.0";

our $DEFAULT_SERVER = "https://www.deadjournal.com/interface/flat";

# userprops used (registered on demand by ensure_props)
our @PROPS = qw(astral_enabled astral_djuser astral_djpass_md5
                astral_server astral_cookie astral_ua astral_last);

LJ::register_hook("postpost", \&crosspost);

# Create our userprop rows if they don't exist yet (safe to call any time;
# no-op once present). Guarded: at image-build time there is no database.
sub ensure_props {
    eval {
        my $dbh = LJ::get_db_writer() or return;
        foreach my $p (@PROPS) {
            $dbh->do("INSERT IGNORE INTO userproplist " .
                     "(name, indexed, cldversion, multihomed, datatype, des, scope) " .
                     "VALUES (?, '0', 0, '0', 'char', ?, 'general')",
                     undef, $p, "Astral Projection: $p");
        }
        # drop this worker's cached prop list so the new rows are visible
        delete $LJ::CACHE_PROP{user};
        delete $LJ::CACHE_PROPID{user};
    };
    return 1;
}

# One flat-protocol call. Returns a hashref of the response dictionary.
sub flat_call {
    my ($server, $fields, $cookie, $agent) = @_;
    my $ua = LWP::UserAgent->new(
        timeout => 25,
        agent   => ($agent || "UnDeadJournal-AstralProjection/$VERSION"),
    );
    my @headers;
    push @headers, (Cookie => $cookie) if $cookie;
    my $res = $ua->post($server, $fields, @headers);
    die "HTTP " . $res->code . " from remote site\n" unless $res->is_success;
    my @lines = split /\n/, $res->content;
    my %out;
    for (my $i = 0; $i < $#lines; $i += 2) {
        $out{$lines[$i]} = $lines[$i+1];
    }
    return \%out;
}

# Verify stored credentials against the remote site (mode=login).
# Returns (1, welcome-name) or (0, error-message).
sub test_login {
    my ($u) = @_;
    LJ::load_user_props($u, @PROPS);
    my $server = $u->{astral_server} || $DEFAULT_SERVER;
    my ($ok, $msg) = (0, "");
    eval {
        my $ch = flat_call($server, { mode => "getchallenge" },
                           $u->{astral_cookie}, $u->{astral_ua});
        die(($ch->{errmsg} || "no challenge from $server") . "\n")
            unless $ch->{challenge};
        my $res = flat_call($server, {
            mode           => "login",
            user           => $u->{astral_djuser},
            auth_method    => "challenge",
            auth_challenge => $ch->{challenge},
            auth_response  => md5_hex($ch->{challenge} . $u->{astral_djpass_md5}),
            ver            => 1,
        }, $u->{astral_cookie}, $u->{astral_ua});
        die(($res->{errmsg} || "login failed") . "\n")
            unless ($res->{success} || "") eq "OK";
        $ok = 1;
        $msg = $res->{name} || $u->{astral_djuser};
    };
    $msg = $@ if $@;
    $msg =~ s/\s+$//;
    return ($ok, $msg);
}

# The postpost hook: project a freshly-posted local entry to the remote site.
sub crosspost {
    my $args = shift;
    my $u = $args->{poster} or return;

    # personal journal posts only
    my $journal = $args->{journal};
    return if $journal && $journal->{userid} != $u->{userid};

    eval { LJ::load_user_props($u, @PROPS) };
    return unless ($u->{astral_enabled} || "") eq "1";
    return unless $u->{astral_djuser} && $u->{astral_djpass_md5};

    my $req   = $args->{req} || {};
    my $props = $req->{props} || {};

    # bulk-import / backdate protection: only project "fresh" entries
    return if $props->{opt_backdated};
    my $drift_ok = eval {
        my $t = timelocal(0, $req->{min} || 0, $req->{hour} || 0,
                          $req->{day}, $req->{mon} - 1, $req->{year});
        abs(time() - $t) < 48 * 3600;
    };
    return unless $drift_ok;

    my $server = $u->{astral_server} || $DEFAULT_SERVER;
    my $outcome;
    eval {
        my $ch = flat_call($server, { mode => "getchallenge" },
                           $u->{astral_cookie}, $u->{astral_ua});
        die(($ch->{errmsg} || "no challenge") . "\n") unless $ch->{challenge};

        my %post = (
            mode           => "postevent",
            user           => $u->{astral_djuser},
            auth_method    => "challenge",
            auth_challenge => $ch->{challenge},
            auth_response  => md5_hex($ch->{challenge} . $u->{astral_djpass_md5}),
            ver            => 1,
            lineendings    => "unix",
            year => $req->{year}, mon => $req->{mon}, day => $req->{day},
            hour => $req->{hour} || 0, min => $req->{min} || 0,
            subject  => defined $req->{subject} ? $req->{subject} : "",
            event    => defined $args->{event} ? $args->{event} : ($req->{event} || ""),
            security => $args->{security} || "public",
        );
        if (($args->{security} || "") eq "usemask") {
            my $mask = $args->{allowmask};
            $mask =~ tr/0-9//cd if defined $mask;   # strip SQL quoting
            $post{allowmask} = $mask || 1;          # default: friends-only
        }
        foreach my $k (qw(current_mood current_moodid current_music
                          current_location taglist opt_preformatted
                          picture_keyword)) {
            $post{"prop_$k"} = $props->{$k}
                if defined $props->{$k} && $props->{$k} ne "";
        }

        my $res = flat_call($server, \%post, $u->{astral_cookie}, $u->{astral_ua});
        die(($res->{errmsg} || "unknown remote error") . "\n")
            unless ($res->{success} || "") eq "OK";
        $outcome = "OK " . time() . " " . ($res->{url} || "posted");
    };
    if ($@) {
        my $err = $@; $err =~ s/\s+/ /g; $err =~ s/\s+$//;
        $outcome = "FAIL " . time() . " " . substr($err, 0, 180);
        warn "AstralProjection crosspost failed for $u->{user}: $err\n";
    }
    eval { $u->set_prop("astral_last", $outcome) };
    return;
}

1;
