#!/bin/bash
# One-time LiveJournal database bootstrap (run by docker-entrypoint.sh on first run).
# The database + 'lj' user are created by the MariaDB container; this builds the
# schema, seeds base data + UI text (incl. the DeadJournal gothic label overrides),
# and creates the admin 'system' account.
set -euo pipefail

export LJHOME="${LJHOME:-/home/lj}"
export PERL5LIB="$LJHOME/cgi-bin"
cd "$LJHOME"

# Note: we do NOT pass --innodb. That flag appends the legacy "TYPE=INNODB" clause
# (and would double up with the schema's own ENGINE= clauses); instead the MariaDB
# service defaults new tables to InnoDB via --default-storage-engine=InnoDB.
# --force-alter: this is a fresh build, so apply every historical ALTER (update-db
# otherwise skips ALTERs as a safety measure on "production" DBs, which then breaks
# follow-up UPDATEs that reference newly-added columns).
# We populate S1 AND S2 system styles + props/base-data/moods. (S2 population
# used to be patched out over a "MySQL server has gone away" crash; the real
# cause — a per-layer fork using a torn-down DB handle — is fixed by a
# Dockerfile patch, so populate_s2() runs normally now.)
echo "[bootstrap] 1/5  global schema + base data (S1+S2 styles, moods, props, jobs)..."
perl bin/upgrading/update-db.pl --runsql --populate --force-alter

echo "[bootstrap] 2/5  user-cluster tables (log2/logtext2/logprop2/logtags on cluster 1)..."
perl bin/upgrading/update-db.pl --cluster=all --runsql --populate --force-alter

echo "[bootstrap] 3/5  loading UI text (English + DeadJournal -local overrides)..."
perl bin/upgrading/texttool.pl load en

echo "[bootstrap] 4/5  creating the 'system' admin account..."
printf '%s\n' "${SYSTEM_PASSWORD:-changeme-system-pass}" | perl bin/upgrading/make_system.pl

echo "[bootstrap] 5/5  config sanity check..."
perl bin/checkconfig.pl || echo "[bootstrap] (checkconfig reported warnings — review above)"

echo "[bootstrap] done. Create your own account at /create.bml, then grant it admin"
echo "[bootstrap] by logging in as 'system' at /admin/priv/ if you want admin tools."
