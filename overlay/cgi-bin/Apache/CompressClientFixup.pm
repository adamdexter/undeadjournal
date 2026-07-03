package Apache::CompressClientFixup;
use strict;
# Optional gzip-compression fixup handler, not shipped in this tree. No-op:
# return DECLINED so the request proceeds normally without client compression.
sub handler { return -1; }
1;
