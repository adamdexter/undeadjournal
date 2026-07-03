package DW::SiteScheme;
use strict;
# Shim: this BML engine calls DW::SiteScheme->get() to detect Dreamwidth's
# Template-Toolkit schemes. Returning undef makes BML fall through to the native
# LiveJournal ".look" scheme renderer, which is what this instance uses.
sub get { return undef; }
our $AUTOLOAD;
sub AUTOLOAD { return; }
sub DESTROY { }
1;
