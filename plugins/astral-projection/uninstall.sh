#!/usr/bin/env bash
# Remove the Astral Projection plugin.
# Then rebuild:  docker compose build web && docker compose up -d
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

echo "Removing Astral Projection..."
rm -f overlay/cgi-bin/LJ/AstralProjection.pm overlay/htdocs/astralprojection.bml
if [ -f overlay/cgi-bin/ljlib-local.pl ]; then
    perl -i -ne 'print unless /AstralProjection/' overlay/cgi-bin/ljlib-local.pl
    # if the file is now just boilerplate, drop it entirely
    if ! grep -qE "^\s*(use|require)\s" overlay/cgi-bin/ljlib-local.pl; then
        rm -f overlay/cgi-bin/ljlib-local.pl
    fi
fi
echo "Removed. Rebuild so it takes effect:"
echo "    docker compose build web && docker compose up -d"
echo "(Your saved settings stay in the database, harmless, in case you reinstall.)"
