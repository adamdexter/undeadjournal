#!/usr/bin/env bash
# backup.sh — dump your entire journal database to backups/journal-YYYY-MM-DD.sql.gz
# Run it any time; the site keeps running. Restore with ./restore.sh <file>.
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "No .env found — run ./setup.sh first."; exit 1; }
# shellcheck disable=SC1091
. ./.env

if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"; else COMPOSE="docker-compose"; fi

mkdir -p backups
out="backups/journal-$(date +%F-%H%M).sql.gz"
echo "Dumping database to $out ..."
$COMPOSE exec -T db sh -c 'exec mysqldump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction livejournal' | gzip > "$out"
size=$(du -h "$out" | cut -f1)
echo "Done: $out ($size)"
echo "Tip: copy your backups/ folder somewhere safe (another disk, cloud storage)."
