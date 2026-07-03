package DW::Request;
use strict;
# Shim: Dreamwidth request/routing layer not used on this LiveJournal-core instance.
our $AUTOLOAD;
sub AUTOLOAD { return; }
sub DESTROY { }
1;
