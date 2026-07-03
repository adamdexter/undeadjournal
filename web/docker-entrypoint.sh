#!/bin/bash
# Entrypoint for the DeadJournal web container.
# Waits for the database, bootstraps the LJ schema on first run (idempotent via a
# DB check, not a file marker), then runs Apache + mod_perl2 in the foreground.
# Note: deliberately NOT using `set -u` — Debian's /etc/apache2/envvars references
# unset variables and would abort the container under nounset.
set -eo pipefail

export LJHOME="${LJHOME:-/home/lj}"
export LJ_SERVERNAME="${LJ_SERVERNAME:-deadjournal.local}"
DB_HOST="${LJ_DB_HOST:-db}"
DB_PASSWORD="${DB_PASSWORD:-ljpass}"

# Apache runtime env (APACHE_RUN_USER/GROUP/PID, APACHE_LOG_DIR, ...)
# shellcheck disable=SC1091
source /etc/apache2/envvars

# var/ and temp/ may be fresh (or volume-mounted) — ensure the apache user can write.
chown -R www-data:www-data "$LJHOME/var" "$LJHOME/temp" 2>/dev/null || true

echo "[entrypoint] waiting for database at $DB_HOST ..."
until mysqladmin ping -h "$DB_HOST" -u lj -p"$DB_PASSWORD" --silent >/dev/null 2>&1; do
    sleep 2
done
echo "[entrypoint] database is up."

# Has the schema been bootstrapped? (Does the 'system' account exist?)
need_boot=1
if booted=$(mysql -h "$DB_HOST" -u lj -p"$DB_PASSWORD" livejournal -N -B \
              -e "SELECT COUNT(*) FROM user WHERE user='system'" 2>/dev/null); then
    [ "${booted:-0}" != "0" ] && need_boot=0
fi

if [ "$need_boot" = "1" ]; then
    echo "[entrypoint] first run — bootstrapping LiveJournal database..."
    /usr/local/bin/bootstrap.sh
else
    echo "[entrypoint] schema already present — skipping bootstrap."
fi

echo "[entrypoint] starting Apache + mod_perl2..."
exec apache2ctl -D FOREGROUND
