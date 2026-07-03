#!/usr/bin/env bash
#
# fetch-authentic-skin.sh — download the authentic DeadJournal artwork.
#
# The classic DeadJournal chrome (skull header/footer, bone borders, stylesheet,
# favicon, mood icons) is copyrighted artwork, so this repository cannot include
# it. This script downloads it to YOUR machine for YOUR personal install:
#
#   - site chrome + icons: from the Internet Archive Wayback Machine's public
#     captures of piktures.deadjournal.com / www.deadjournal.com (2006 era)
#   - "SK Cute Skulls" mood icons: from the Dreamwidth open-source repository
#
# Run it from the repo root (setup.sh does this for you):  scripts/fetch-authentic-skin.sh
# Re-run with --force to re-download everything.
#
# If you skip this script, the site still works — it just uses the plain
# classic-LiveJournal look (set LJ_SCHEME=bluewhite in .env).

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

WB="https://web.archive.org/web/20060615id_"       # nearest-capture redirect is fine
PIK="http://piktures.deadjournal.com"
DW_RAW="https://raw.githubusercontent.com/dreamwidth/dreamwidth/main/htdocs"
UA="Mozilla/5.0 (compatible; undeadjournal-skin-fetch)"

IMG_DIR="overlay/htdocs/img"
MOOD_DIR="$IMG_DIR/mood/skcuteskulls"
mkdir -p "$IMG_DIR" "$MOOD_DIR"

ok=0; skipped=0; failed=0
FAILED_LIST=""

fetch() { # fetch <url> <dest> <type-regex>
    local url="$1" dest="$2" want="$3"
    if [ $FORCE -eq 0 ] && [ -s "$dest" ]; then
        skipped=$((skipped+1)); return 0
    fi
    local tmp="$dest.part"
    if curl -sfL --retry 3 --connect-timeout 20 -A "$UA" -o "$tmp" "$url"; then
        if file -b "$tmp" | grep -qiE "$want"; then
            mv "$tmp" "$dest"; ok=$((ok+1))
            printf '  got  %s\n' "$dest"
            return 0
        fi
        printf '  BAD  %s (wrong file type: %s)\n' "$dest" "$(file -b "$tmp" | head -c 40)"
    else
        printf '  FAIL %s\n' "$url"
    fi
    rm -f "$tmp"; failed=$((failed+1)); FAILED_LIST="$FAILED_LIST $dest"
    return 1
}

echo "Fetching the authentic DeadJournal artwork (Internet Archive)..."
echo "   (these are public Wayback Machine captures; be patient, archive.org is slow)"

# --- site chrome (piktures.deadjournal.com, 2006 captures) ---
for f in deadjournal_header_01.jpg deadjournal_header_02.jpg deadjournal_header_03.jpg \
         deadjournal_header_04.jpg deadjournal_header_05.jpg \
         deadjournal_footer_02.jpg deadjournal_footer_03.jpg deadjournal_footer_04.jpg \
         deadjournal_footer_05.jpg deadjournal_footer_06.jpg \
         dj_leftback.jpg dj_midback.jpg dj_rightback.jpg; do
    fetch "$WB/$PIK/$f" "$IMG_DIR/$f" "JPEG"
done
fetch "$WB/$PIK/miniskull.gif"  "$IMG_DIR/miniskull.gif"  "GIF"
fetch "$WB/$PIK/userinfo.gif"   "$IMG_DIR/userinfo.gif"   "GIF"
fetch "$WB/$PIK/tomb-small.png" "$IMG_DIR/tomb-small.png" "PNG"
fetch "$WB/$PIK/favicon.ico"    "overlay/htdocs/favicon.ico" "icon|ico|image"

# --- the stylesheet (byte-identical on the site from 2006 through 2022) ---
fetch "$WB/http://www.deadjournal.com/djstyle.css" "overlay/htdocs/djstyle.css" "ASCII|text"

# --- "SK Cute Skulls" mood icons (from the open-source Dreamwidth repo).
#     The file list is derived from our own moods.dat so it stays in sync. ---
echo "Fetching the skull mood icons (Dreamwidth repository)..."
while read -r path; do
    fetch "$DW_RAW$path" "$MOOD_DIR/$(basename "$path")" "GIF" || true
done < <(awk '/^MOODTHEME SK Cute Skulls/{f=1;next} /^MOODTHEME /{f=0} f && /^[0-9]/{print $2}' \
    overlay/bin/upgrading/moods.dat)
moods_present=$(ls "$MOOD_DIR" 2>/dev/null | wc -l | tr -d ' ')

echo
echo "Done: $ok downloaded, $skipped already present, $failed failed. Mood icons present: $moods_present/35."
if [ $failed -gt 0 ]; then
    echo "Some downloads failed:$FAILED_LIST"
    echo "archive.org rate-limits sometimes — just run this script again in a minute."
    exit 1
fi
echo "Authentic skin ready. (If the site is already built, re-run ./setup.sh or"
echo "'docker compose build web && docker compose up -d' so it gets baked in.)"
