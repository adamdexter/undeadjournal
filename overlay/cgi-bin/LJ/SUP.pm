package LJ::SUP;
use strict;
# Stub: LJ::SUP is SUP's (the 2007+ Russian LJ owner) market-segmentation
# module — never open-sourced, but called unguarded by manage/profile and
# misc/suggest_qotd (LJ::SUP->is_remote_sup). Real deployments preloaded it;
# here LJ::DeadJournalChildInit does. AUTOLOAD returns undef, so every
# is-this-a-SUP-user check answers no.
our $AUTOLOAD;
sub AUTOLOAD { return; }
sub DESTROY { }
1;
