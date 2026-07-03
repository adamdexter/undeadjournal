#!/usr/bin/env bash
# Install the Astral Projection plugin (parallel-publish to the real
# deadjournal.com). Run from anywhere:  plugins/astral-projection/install.sh
# Then rebuild:  docker compose build web && docker compose up -d
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
SRC="plugins/astral-projection/files"

echo "Installing Astral Projection..."
mkdir -p overlay/cgi-bin/LJ overlay/htdocs
cp "$SRC/cgi-bin/LJ/AstralProjection.pm" overlay/cgi-bin/LJ/AstralProjection.pm
cp "$SRC/htdocs/astralprojection.bml"    overlay/htdocs/astralprojection.bml

# ljlib-local.pl is the engine's "local additions" file — create it, or append
# our loader if one already exists for other purposes.
if [ -f overlay/cgi-bin/ljlib-local.pl ]; then
    if grep -q "AstralProjection" overlay/cgi-bin/ljlib-local.pl; then
        echo "  ljlib-local.pl already loads AstralProjection."
    else
        # insert the use line before the final "1;"
        perl -i -pe 's/^1;\s*$/use LJ::AstralProjection;\n1;\n/' overlay/cgi-bin/ljlib-local.pl
        echo "  appended loader to existing ljlib-local.pl."
    fi
else
    cp "$SRC/cgi-bin/ljlib-local.pl" overlay/cgi-bin/ljlib-local.pl
fi

echo
echo "Installed. Now rebuild so it takes effect:"
echo "    docker compose build web && docker compose up -d"
echo
echo "Then log in and open /astralprojection.bml (also linked in the sidebar"
echo "under RIP <your name> -> Astral Projection) to configure and enable it."
