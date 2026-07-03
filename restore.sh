#!/usr/bin/env bash
# restore.sh — restore a backup made by ./backup.sh
# Usage: ./restore.sh backups/journal-2026-07-02-1200.sql.gz
# WARNING: replaces the CURRENT database contents with the backup.
set -euo pipefail
cd "$(dirname "$0")"

f="${1:-}"
[ -n "$f" ] && [ -f "$f" ] || { echo "Usage: ./restore.sh <backups/journal-....sql.gz>"; ls -1 backups/ 2>/dev/null; exit 1; }
[ -f .env ] || { echo "No .env found — run ./setup.sh first."; exit 1; }

if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"; else COMPOSE="docker-compose"; fi

echo "This will REPLACE the current journal database with: $f"
read -r -p "Type 'restore' to continue: " sure
[ "$sure" = "restore" ] || { echo "Cancelled."; exit 1; }

echo "Restoring..."
gunzip -c "$f" | $COMPOSE exec -T db sh -c 'exec mysql -uroot -p"$MARIADB_ROOT_PASSWORD" livejournal'
$COMPOSE restart memcached web >/dev/null
echo "Done. Your journal is restored."
