package LJ::UserApps::Activities;
use strict;
# Stub: SUP-era third-party-applications activity feed, use'd at compile time
# by userinfo.bml (so the file must exist even though the userapps list is
# always empty here). get_last must return an ARRAYREF — callers do @$result.
sub get_last { return []; }
our $AUTOLOAD;
sub AUTOLOAD { return; }
sub DESTROY { }
1;
