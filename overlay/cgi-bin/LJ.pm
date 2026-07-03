#!/usr/bin/perl
#
# LJ.pm — loader shim.
#
# This archived LiveJournal mirror (apparentlymart/livejournal) is missing the
# top-level cgi-bin/LJ.pm that ~106 source files expect via `use LJ;`. The actual
# core package LJ lives in cgi-bin/ljlib.pl (which begins `package LJ;`), and was
# historically loaded with `require "ljlib.pl"`. This shim bridges the two so the
# modern `use LJ;` call sites work, exactly as the original top-level LJ.pm did.
package LJ;
use strict;

require "$ENV{'LJHOME'}/cgi-bin/ljlib.pl";

1;
