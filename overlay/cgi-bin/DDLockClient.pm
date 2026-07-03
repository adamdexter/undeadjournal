package DDLockClient;
use strict;
# Stub: ddlockd distributed-lock client. Not used on a single-server instance
# (LiveJournal falls back to MySQL GET_LOCK). Present so the unconditional `use`
# compiles; methods are no-ops if ever called.
sub new { return bless {}, (ref $_[0] || $_[0]); }
our $AUTOLOAD;
sub AUTOLOAD { return; }
sub DESTROY { }
1;
