package LJ::DeadJournalChildInit;
use strict;
# Preload the LJ::SUP stub: manage/profile and misc/suggest_qotd call
# LJ::SUP->is_remote_sup without use'ing it (real SUP deployments preloaded
# the module), so it has to be in memory before any request runs.
use LJ::SUP;

# mod_perl prefork fix: the parent process connects to the master DB at config
# load (e.g. LJ::Lang::init_bml in modperl.pl). Forked children inherit that
# handle, which is invalid in the child — so get_db_writer()/get_dbh("master")
# returns undef in some request paths (notably journal rendering), while readers
# that connect fresh in-child work. Disconnecting on child init forces every
# child to establish its own connections on demand.
sub handler {
    eval { LJ::disconnect_dbs(); };
    return 0;
}

1;
