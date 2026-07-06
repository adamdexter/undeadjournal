#!/usr/bin/perl
# -*-perl-*-
#
# DeadJournal — site configuration for the authentic classic LiveJournal engine.
# Loaded from $LJHOME/etc/ljconfig.pl (the cgi-bin/ location is deprecated).
#
# This is a minimal, single-private-user configuration. Defaults for everything
# not set here come from cgi-bin/ljdefaults.pl. Deployment-specific values are
# read from the environment (set in docker-compose.yml) so this file is portable.

{
    package LJ;

    ###
    ### Paths
    ###
    $HOME   = $ENV{'LJHOME'};
    $HTDOCS = "$HOME/htdocs";
    $BIN    = "$HOME/bin";
    $TEMP   = "$HOME/temp";
    $VAR    = "$HOME/var";

    ###
    ### Site identity / branding (SITE_NAME comes from .env via docker-compose)
    ###
    $SITENAME      = $ENV{'SITE_NAME'} || "DeadJournal";
    $SITENAMESHORT = $SITENAME;
    $SITENAMEABBREV = join('', map { uc substr($_, 0, 1) } split /\s+/, $SITENAME) || "DJ";

    # How the site is reached (host:port and full URL; set in .env).
    $DOMAIN   = $ENV{'LJ_DOMAIN'}   || "localhost:8080";
    $SITEROOT = $ENV{'LJ_SITEROOT'} || "http://$DOMAIN";
    $IMGPREFIX  = "$SITEROOT/img";
    $STATPREFIX = "$SITEROOT/stc";
    $USERPIC_ROOT = "$SITEROOT/userpic";

    # Host-only session cookies. $DOMAIN may carry a port (LJ_DOMAIN=host:8080)
    # and a cookie Domain attribute must never contain one — browsers reject
    # the cookie and login silently bounces back logged-out. An empty domain
    # binds the cookie to the exact host, which is right for this single-host
    # deploy (localhost, LAN IP, or Tailscale name alike). Kept as an arrayref
    # so ljdefaults.pl's `$COOKIE_DOMAIN ||= ".$DOMAIN"` can't clobber it.
    $COOKIE_DOMAIN = [""];
    $COOKIE_PATH   = "/";

    $ADMIN_EMAIL     = "admin\@$DOMAIN";
    $SUPPORT_EMAIL   = "support\@$DOMAIN";
    $COMMUNITY_EMAIL = "community\@$DOMAIN";
    $BOGUS_EMAIL     = "dontreply\@$DOMAIN";

    ###
    ### Policy — relaxed for a private single-user box (no mail server)
    ###
    $EVERYONE_VALID = 1;   # auto-validate accounts (no confirmation email needed)
    $TOS_CHECK      = 0;   # don't require Terms-of-Service agreement flow
    $COPPA_CHECK    = 0;

    # Disable the event/notification subsystem (ESN). On a single-user journal we
    # don't need inbox/email notifications, and this keeps postevent from queueing
    # notification jobs. (TheSchwartz is still configured below for the few jobs
    # that are always fired, so insert_jobs always has a valid home.)
    %DISABLED = (
        'esn'             => 1,
        'esn-userevents'  => 1,
        'tellafriend'     => 1,
    );

    ###
    ### Database (MariaDB container service "db")
    ###
    my $dbpass = $ENV{'DB_PASSWORD'} || 'ljpass';

    %DBINFO = (
        'master' => {
            'host'   => 'db',
            'port'   => 3306,
            'user'   => 'lj',
            'pass'   => $dbpass,
            'dbname' => 'livejournal',
            # Single-server setup: the one DB serves every role (master + the
            # 'slave'/reader role get_db_reader() asks for + cluster 1).
            'role'   => {
                'master'   => 1,
                'slave'    => 1,
                'cluster1' => 1,
            },
        },
    );

    @CLUSTERS        = (1);
    $DEFAULT_CLUSTER = [ 1 ];
    $SYND_CLUSTER    = 1;
    $DIR_DB_HOST     = "master";
    $DIR_DB          = "";

    ###
    ### memcached
    ###
    @MEMCACHE_SERVERS = ('memcached:11211');
    $MEMCACHE_COMPRESS_THRESHOLD = 1_000;

    ###
    ### TheSchwartz job queue — point it at the same MariaDB (the sch_* tables are
    ### created by bin/upgrading/update-db.pl). Without this, theschwartz() builds
    ### a client from an empty DB list and insert_jobs() can fail at runtime.
    ###
    %THESCHWARTZ_DBS = (
        'main' => {
            'dsn'    => "dbi:mysql:livejournal;host=db",
            'user'   => 'lj',
            'pass'   => $dbpass,
            'prefix' => 'sch_',
        },
    );
    %THESCHWARTZ_DBS_ROLES = (
        'default' => [ 'main' ],
        'worker'  => [ 'main' ],
        'mass'    => [ 'main' ],
    );
    # theschwartz() defaults to this role when none is passed (e.g. postevent's
    # job enqueue). Without it the role is '' and postevent dies after saving.
    $THESCHWARTZ_ROLE_DEFAULT = 'default';

    ###
    ### Mail (no MTA on this box) — route to localhost; sends will simply fail
    ### harmlessly. With ESN disabled and EVERYONE_VALID, mail is rarely triggered.
    ###
    $SMTP_SERVER = "127.0.0.1";

    ###
    ### Unicode — keep enabled (posts are UTF-8; required for ver>=1 protocol posts)
    ###
    $UNICODE = 1;

    ###
    ### Schemes (site chrome). First entry is the default → the DeadJournal skin.
    ### This 2011-era engine uses the BML ".look" scheme system: 'deadjournal'
    ### resolves to cgi-bin/bml/scheme/deadjournal.look (the Dockerfile also sets
    ### it as the BML DefaultScheme).
    @SCHEMES = (
        { scheme => 'deadjournal',     title => 'DeadJournal 2003' },
        { scheme => 'deadjournal2015', title => 'DeadJournal 2015' },
        { scheme => 'deadjournal2025', title => 'DeadJournal 2025 (responsive)' },
        { scheme => 'bluewhite',       title => 'Blue/White' },
        { scheme => 'lynx',            title => 'Lynx' },
    );
    $MINIMAL_BML_SCHEME = 'lynx';

    ###
    ### S1 is the 2003-era journal style system (classes .meta/.entrybox/.caption).
    ### Keep the default S1 generator style available.
    ###
    # No S2 default style (S2 layers aren't populated; DeadJournal uses S1). New
    # journals fall back to the S1 default rendering.
    $S2COMPILED_MIGRATION_DONE = 1;

    ###
    ### OpenID — server on (harmless), consumer off
    ###
    $OPENID_SERVER   = 1;
    $OPENID_CONSUMER = 0;

    # No MogileFS: userpics/captchas are stored as DB blobs instead of on a
    # MogileFS cluster. (Leaving %MOGILEFS_CONFIG unset is what enables this.)
    $DISABLE_MEDIA_UPLOADS = 0;

    $RANDOM_USER_PERIOD = 7;
    $NEWUSER_CAPS = 2;
}

1;
