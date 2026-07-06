# Authentic classic LiveJournal (DeadJournal-skinned) — web container
#
# Base: Debian 9 "stretch" from archive.debian.org. This is the only toolchain
# that Dockerizes the 2014 LiveJournal tree using prebuilt distro packages:
#   Perl 5.24, Apache 2.4, libapache2-mod-perl2 2.0.10.
# The tree's own docs recommend Apache 1.3 / mod_perl 1, but the code ships
# cgi-bin/LJ/Request/Apache2.pm and branches on MOD_PERL_API_VERSION==2, so we
# run it under mod_perl2. (If it fights at runtime, see README "mod_perl2 risk".)
#
# Source: github.com/apparentlymart/livejournal  (archived; pinned below)
FROM debian:stretch

# Pin to a Jan-2011 commit: the latest state that is COMPLETE (the 2014 HEAD is
# missing ~36 SUP-era proprietary modules that were never open-sourced) AND has
# mod_perl2 support (added 2010-01) AND keeps the web router intact. Period-correct
# for the DeadJournal era, and it actually builds.
ARG LJ_COMMIT=7f92f9395323fca77b4061b5140011ae96b32d66

ENV LJHOME=/home/lj \
    PERL5LIB=/home/lj/cgi-bin:/home/lj/src/DSMS/lib \
    DEBIAN_FRONTEND=noninteractive

# --- EOL apt: point at archive.debian.org. Both main AND security are required:
#     the final stretch apache2/git metapackages depend on deb9u* versions of
#     apache2-bin / libcurl3-gnutls that live in the security suite. ---
RUN set -eux; \
    { echo 'deb http://archive.debian.org/debian stretch main'; \
      echo 'deb http://archive.debian.org/debian-security stretch/updates main'; \
    } > /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid; \
    echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/99retries

# --- Core infrastructure — these MUST install (fresh apt-get update in-layer). ---
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      apache2 libapache2-mod-perl2 libapache2-request-perl perl cpanminus build-essential \
      git ca-certificates default-mysql-client; \
    rm -rf /var/lib/apt/lists/*

# --- Perl module packages (distro binaries; never build XS like GD/DBD::mysql
#     from CPAN). Installed tolerantly per-package: a renamed or missing one
#     falls through to the CPAN backstop and the checkconfig gate at the end, so
#     a single bad package name can't abort the whole build. (libgd-perl and
#     libgd-gd2-perl are alternate names for GD across Debian releases.) ---
RUN set -eux; \
    apt-get update; \
    for p in libdatetime-perl libdbi-perl libdbd-mysql-perl libclass-autouse-perl \
             libdigest-sha1-perl libhtml-template-perl libimage-size-perl libmime-lite-perl \
             libnet-dns-perl liburi-perl libhtml-tagset-perl libhtml-parser-perl libwww-perl \
             libmailtools-perl libunicode-maputf8-perl libxml-simple-perl libio-stringy-perl \
             libdigest-hmac-perl libgd-perl libgd-gd2-perl libmime-tools-perl \
             libcache-memcached-perl libsoap-lite-perl libjson-perl libjson-xs-perl \
             liblwpx-paranoidagent-perl libnet-openid-consumer-perl libnet-openid-server-perl \
             libgearman-client-perl libipc-run-perl; do \
      apt-get install -y --no-install-recommends "$p" 2>/dev/null && echo "ok: $p" || echo "WARN: missing $p (CPAN will backstop)"; \
    done; \
    rm -rf /var/lib/apt/lists/*

# --- Best-effort optional/uncertain distro packages (won't fail the build if a
#     package name is absent on stretch; cpanm below backstops the required ones). ---
RUN set -eux; \
    for p in libcaptcha-recaptcha-perl libtheschwartz-perl libgd-graph-perl \
             librpc-xml-perl libxml-rss-perl libstring-crc32-perl \
             libcrypt-dh-perl liburi-fetch-perl libclass-trigger-perl \
             libclass-accessor-perl libclass-data-inheritable-perl; do \
      apt-get update >/dev/null 2>&1 || true; \
      apt-get install -y --no-install-recommends "$p" 2>/dev/null && echo "installed $p" || echo "skip $p"; \
    done; \
    rm -rf /var/lib/apt/lists/*

# --- Required modules with no Debian package (XS / not packaged). These are
#     use'd unconditionally by the bootstrap and ljlib, and checkconfig does NOT
#     flag MogileFS/TheSchwartz, so install them explicitly. ---
RUN set -eux; \
    cpanm --notest --no-man-pages \
      Digest::SHA1 \
      Unicode::CheckUTF8 \
      Captcha::reCAPTCHA \
      MogileFS::Client \
      TheSchwartz

# --- LiveJournal source tree (fetch the pinned complete+mp2 commit) ---
RUN set -eux; \
    mkdir -p "$LJHOME"; \
    git -C "$LJHOME" init -q; \
    git -C "$LJHOME" remote add origin https://github.com/apparentlymart/livejournal.git; \
    git -C "$LJHOME" fetch --depth 1 origin "$LJ_COMMIT"; \
    git -C "$LJHOME" checkout -q FETCH_HEAD; \
    rm -rf "$LJHOME/.git"

# --- Modern-Perl (5.24) compatibility patches for the 2011 code ---
# The 2011 source predates several Perl deprecations/removals. Patch them here so
# the engine runs on Debian stretch's Perl 5.24. (Grown as issues are found.)
RUN set -eux; \
    # UNIVERSAL stopped exporting isa()/can() in modern Perl (use it bare).
    sed -i 's/^use UNIVERSAL qw(isa);/use UNIVERSAL ();/' "$LJHOME/cgi-bin/LJ/Text.pm"; \
    # The old "TYPE=<engine>" CREATE-TABLE clause was removed in MySQL 5.5 / MariaDB;
    # rewrite to "ENGINE=<engine>" throughout the schema-generation code.
    find "$LJHOME/bin/upgrading" -type f \( -name '*.pl' -o -name '*.sql' \) \
         -exec sed -i -E 's/\b[Tt][Yy][Pp][Ee]=([A-Za-z]+)/ENGINE=\1/g' {} +; \
    # defined(@array) / defined(%hash) were removed in Perl 5.22 (fatal); drop defined().
    find "$LJHOME/cgi-bin" -type f \( -name '*.pl' -o -name '*.pm' \) \
         -exec perl -i -pe 's/\bdefined\s+([@%][\w:]+)/$1/g; s/\bdefined\s*\(\s*([@%][\w:]+)\s*\)/$1/g' {} +; \
    # Apache 2.4 dropped Apache2::Connection->remote_ip (now ->client_ip). Alias it
    # globally so every legacy ->remote_ip caller (LJ::Request, ljprotocol.pl, ...)
    # keeps working. Appended to LJ/Request/Apache2.pm, which loads at startup.
    { echo ''; echo 'package Apache2::Connection;'; \
      echo 'sub remote_ip { my $c = shift; return $c->client_ip(@_); }'; \
      echo '1;'; } >> "$LJHOME/cgi-bin/LJ/Request/Apache2.pm"; \
    # procnotify_check (cross-process cache invalidation; unneeded on a single
    # server) can run before the request DB handle is ready; guard the undef.
    sed -i 's|my $max = $dbr->selectrow_array("SELECT MAX(nid) FROM procnotify");|my $max = $dbr ? $dbr->selectrow_array("SELECT MAX(nid) FROM procnotify") : undef;|' "$LJHOME/cgi-bin/ljlib.pl"; \
    # Skip S2 system-style population: compiling the S2 layers triggers a fatal
    # "MySQL server has gone away" that aborts the rest of populate. DeadJournal is
    # S1-era; S1 styles still populate. (Comment out only the populate_s2() call.)
    sed -i 's|^\(\s*\)populate_s2();|\1print "Skipping S2 style population (DeadJournal uses S1).\\n";|' "$LJHOME/bin/upgrading/update-db.pl"; \
    # Make the site scheme configurable at runtime (the engine reads
    # $env->{DefaultScheme}; lj-bml-init.pl sets BML config at startup).
    # LJ_SCHEME=deadjournal (authentic chrome; needs the fetched artwork) or
    # LJ_SCHEME=bluewhite (stock LJ look, no artwork needed).
    printf '\nBML::set_config("DefaultScheme", $ENV{LJ_SCHEME} || "deadjournal");\n1;\n' >> "$LJHOME/cgi-bin/lj-bml-init.pl"; \
    # texttool.pl die()s on htdocs/*.text.local files when DEFAULT_LANG is "en"
    # (a .local file implies a non-en default). We use en, so skip those files
    # instead of dying — otherwise the text-load aborts and EVERY UI label across
    # the site renders blank (empty login form, etc.).
    sed -i 's|die "uh, what is this .local file?" unless $lang ne "en";|next if $lang eq "en";|' "$LJHOME/bin/upgrading/texttool.pl"; \
    # alloc_global_counter("ml_latest_updates_counter") relies on a SUP-era hook we
    # don't have, so it returns undef → the ml_latest REPLACE gets an empty revid
    # (SQL syntax error) → text loading aborts and all UI labels stay blank. revid
    # only tracks incremental ML sync (unused on a one-time load); default it to 0.
    sed -i 's@LJ::alloc_global_counter("ml_latest_updates_counter");@LJ::alloc_global_counter("ml_latest_updates_counter") || 0;@' "$LJHOME/cgi-bin/ljlang.pl"; \
    # 2003-era authenticity: remove the OpenID/Facebook/Twitter "or connect using"
    # block from the login page (social login is a ~2011 anachronism for DeadJournal).
    sed -i '/\.or\.connect\.using/d; /icons\/openid-32\.gif/d' "$LJHOME/htdocs/login.bml"; \
    # Session cookies: LJ_DOMAIN carries a port (host:8080), but a cookie
    # Domain attribute must never contain one — browsers reject the cookie and
    # web login silently bounces back to the homepage logged out. Session.pm's
    # own set_cookie (used for ljmastersession/ljloggedin/BMLschemepref) takes
    # $LJ::DOMAIN verbatim and ignores $LJ::COOKIE_DOMAIN, so normalize there:
    # strip the port, and drop the attribute for dotless hosts (localhost, bare
    # NAS names) — host-only cookies are the only variant all browsers accept.
    sed -i 's|my $domain[[:space:]]*=[[:space:]]*delete $opts{domain};|my $domain = delete $opts{domain}; if ($domain) { $domain =~ s/:[0-9]+$//; $domain = q{} unless $domain =~ /[.]/; }|' "$LJHOME/cgi-bin/LJ/Session.pm"; \
    grep -q 'q{} unless' "$LJHOME/cgi-bin/LJ/Session.pm"; \
    # (The BML _code calling-convention fix lives in overlay/cgi-bin/Apache/
    # BML.pm — a harvested overlay file, not part of the fetched tree.)
    # Drop the SUP-era "secret question" tile from /manage/settings/: its
    # userprop (secret_question_text) has no definition in this tree, so the
    # prop-storage handler croaks and the whole settings page dies. (Secret
    # questions are a mid-2000s SUP feature — an anachronism here anyway.)
    sed -i '/LJ::Setting::Display::SecretQuestion/d' "$LJHOME/htdocs/manage/settings/index.bml"; \
    ! grep -q 'SecretQuestion' "$LJHOME/htdocs/manage/settings/index.bml"; \
    # DeadJournal-brand the S1 journal styles the way the live site does:
    # "livejournal userinfo" → "deadjournal userinfo", and the calendar view
    # is called the "archive" ("journal archive") on DeadJournal. Link labels
    # only — hrefs (/calendar/ URLs) are untouched.
    sed -i 's|>livejournal userinfo<|>deadjournal userinfo<|g; s|>livejournal calendar<|>journal archive<|g; s|>calendar<|>archive<|g' "$LJHOME/bin/upgrading/s1styles.dat"; \
    grep -q 'deadjournal userinfo' "$LJHOME/bin/upgrading/s1styles.dat"; \
    # editjournal.bml uses "%POST->{$_}" — the hash-as-a-reference idiom,
    # deprecated forever and REMOVED in Perl 5.22 ("Can't use a hash as a
    # reference"); the page dies on load. Sole occurrence in the tree.
    sed -i 's|%POST->{$_}|$POST{$_}|' "$LJHOME/htdocs/editjournal.bml"; \
    ! grep -qF '%POST->' "$LJHOME/htdocs/editjournal.bml"

# --- DeadJournal overlay: etc/ljconfig.pl, the SiteScheme, skin assets,
#     gothic label overrides (merged on top of $LJHOME). ---
COPY overlay/ $LJHOME/

# --- Apache wiring ---
COPY web/lj.conf /etc/apache2/conf-available/lj.conf
COPY web/deadjournal.vhost.conf /etc/apache2/sites-available/deadjournal.conf
COPY web/bootstrap.sh /usr/local/bin/bootstrap.sh
COPY web/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN set -eux; \
    chmod +x /usr/local/bin/bootstrap.sh /usr/local/bin/docker-entrypoint.sh; \
    # The 2011 mod_perl/DBI code is NOT thread-safe (DB handles live in package
    # globals). It must run under the prefork MPM, not Debian's default event MPM,
    # or DB handles intermittently come back undef across threads.
    a2dismod mpm_event mpm_worker 2>/dev/null || true; \
    a2enmod mpm_prefork; \
    a2enmod perl; \
    a2enconf lj; \
    a2dissite 000-default; \
    a2ensite deadjournal; \
    # var/ and temp/ must be writable by the apache user at runtime
    mkdir -p "$LJHOME/var" "$LJHOME/temp"; \
    chown -R www-data:www-data "$LJHOME/var" "$LJHOME/temp" "$LJHOME/htdocs"

# --- Fail the build early if any REQUIRED Perl module is missing ---
RUN perl "$LJHOME/bin/checkconfig.pl" --only=modules

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
