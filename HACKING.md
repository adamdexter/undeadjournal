# HACKING.md — how this actually works

For people (and AI agents) modifying the engine. The upstream LiveJournal
archive does NOT run out of the box; this document records every intervention
that makes it run, with the failure symptom each one fixes. Regressions here
are how you get mystery 500s.

## Architecture / non-negotiables

| Piece | Choice | Why it MUST be this |
|---|---|---|
| Engine source | `apparentlymart/livejournal` @ `7f92f93...` (Jan 2011) | The 2014 HEAD is missing ~36 proprietary "SUP-era" modules → incomplete. This is the last commit that is complete AND has mod_perl2. (`ARG LJ_COMMIT` in `web/Dockerfile`.) |
| OS base | `debian:stretch` via `archive.debian.org` | Only toolchain that provides prebuilt Perl 5.24 / Apache 2.4 / mod_perl2 2.0.10 / libapreq2 for this tree. Both `main` + `security` apt suites are required. |
| Apache MPM | **prefork** (never event/worker) | DB handles live in Perl package globals — not thread-safe. Under a threaded MPM, handles intermittently come back undef. |
| DB | `mariadb:10.6`, `latin1` + empty `sql-mode` | The engine stores raw UTF-8 bytes in latin1 columns and never issues `SET NAMES`. MySQL 8 breaks it multiple ways. |
| Style system | **S1** (S2 population skipped) | DeadJournal is S1-era, and the S2 layer compiler kills the bootstrap (see below). |
| Client protocol | **flat** (`/interface/flat`) | The XML-RPC endpoint 404s in this build. Import/export scripts use flat with challenge/response auth. |

## Compatibility patches (web/Dockerfile), each with its symptom

Applied to the freshly-cloned tree BEFORE `COPY overlay/`:

1. `use UNIVERSAL qw(isa)` → `use UNIVERSAL ()` — *(compile error on modern Perl)*
2. `TYPE=<engine>` → `ENGINE=<engine>` in `bin/upgrading` — *(every CREATE TABLE fails on MariaDB)*
3. strip `defined(@array)` / `defined(%hash)` — *(fatal since Perl 5.22)*
4. append `Apache2::Connection::remote_ip` → `client_ip` alias — *(Apache 2.4 removed it; posting + journal views die)*
5. guard `procnotify_check`'s undef `$dbr` — *(crash before request DB handle exists)*
6. comment out `populate_s2()` — *(S2 layer compile → "MySQL server has gone away" → aborts the REST of populate: props, moods, base data)*
7. append `BML::set_config("DefaultScheme", $ENV{LJ_SCHEME} || "deadjournal")` — *(no default scheme → unskinned pages)*
8. `texttool.pl`: don't die on `*.text.local` files when the default language is `en` — *(text load aborts → EVERY UI label on the site renders blank)*
9. `ljlang.pl`: `alloc_global_counter(...) || 0` — *(missing SUP hook → undef revid → SQL syntax error → same blank-label symptom)*
10. `login.bml`: remove the OpenID/Facebook/Twitter block — *(2011 anachronism; this is a 2003 experience)*

## Overlay / Apache config (the other half)

- **`web/lj.conf`: `PerlPassEnv DB_PASSWORD`** — the single nastiest bug in the
  revival. mod_perl exposes NO env vars to Perl workers unless passed, so
  `ljconfig.pl`'s `$ENV{DB_PASSWORD}` was empty → connects with the fallback
  password → `Access denied` → `get_db_reader()` undef → journal pages 500
  *only* in the rendering path. Same for `SITE_NAME`, `LJ_SCHEME`, `LJ_*`.
- **`PerlChildInitHandler LJ::DeadJournalChildInit`** — drops DB handles
  inherited from the Apache parent so each prefork child reconnects fresh.
- **`PerlOptions +GlobalRequest`** (vhost) — BML needs the global request;
  without it every BML page 500s.
- **`overlay/cgi-bin/DBI/Role.pm`** — `connection_bad()` returns 0: the
  original ran `SHOW REPLICA STATUS`, which errors (1227) on every check
  against MariaDB and poisons the handle.
- **`overlay/cgi-bin/`** — ~70 modules: 6 real transplants from Dreamwidth
  (`LJ.pm` loader, `DBI::Role`, `HTMLCleaner`, `CSS/Cleaner`, `S2/Color`, the
  whole `Apache/BML.pm` page engine + `overlay/src/s2/` compiler) and ~30
  hand-written no-op stubs for never-open-sourced modules (`LJ/GeoLocation`,
  `LJ/Pay/*`, `LJ/SMS/*`, `DDLockClient`, ...). Stub pattern:
  `sub AUTOLOAD { return; } sub new { bless {}, shift }`.
- **`overlay/etc/ljconfig.pl`** — single-server `%DBINFO` (master serves
  master+slave+cluster1 roles), `$THESCHWARTZ_ROLE_DEFAULT='default'`
  (postevent dies without it), ESN disabled, `$EVERYONE_VALID=1`.

## Bootstrap (web/bootstrap.sh) landmines

`update-db.pl --runsql --populate --force-alter` (global, then `--cluster=all`),
`texttool.pl load en`, `make_system.pl`. Guarded to run once (checks for the
`system` user). Don't remove `--force-alter` (historical ALTERs get skipped as
a "production safety" and later UPDATEs fail); don't add `--innodb` (legacy
`TYPE=` clause). `overlay/bin/upgrading/moods.dat` supplies the 132-mood set
(upstream ships none); "SK Cute Skulls" is first → `moodthemeid=1` → the
`user` table default → skull mood icons for everyone.

## The skin, technically

- Site chrome = `overlay/cgi-bin/bml/scheme/deadjournal.look` — a BML "look"
  scheme (`KEY=>value` blocks; `_parent=>global.look`) overriding `PAGE` with
  the faithful 2006 markup (centered 800px table, sidebar nav, imagemaps).
  This engine does NOT use `templates/SiteScheme/*.tmpl` — don't add one.
- Journal pages = per-user S1 override: `create.bml` saves
  `overlay/etc/gothic-s1-override.txt` via `LJ::S1::save_overrides` and sets
  `useoverrides='Y'` (the gate in `LJ/User.pm`). Two traps it works around:
  `create_account()`'s return fails `LJ::isu()` (reload with `LJ::load_user`),
  and `LJ::S1::` only exists after `require ljviews.pl`.
- Artwork is fetched at install time (`scripts/fetch-authentic-skin.sh`) into
  gitignored paths under `overlay/htdocs/` — then baked into the image at
  build. Changed art ⇒ rebuild.

## Debugging traps (learned the hard way)

- `$ENV{LJHOME}` is empty inside BML `<?_code?>` blocks — use `$LJ::HOME`.
- BML page files close the page block with `page?>`, **not** `?>`.
- Literal wide characters (é, —) in Perl code that prints → "Wide character in
  subroutine entry" 500s. Use HTML entities.
- BML error-log lines contain literal `\n` — unescape when reading:
  `perl -0777 -ne 's/\\n/\n/g; print' error.log`
- memcached caches styles and userprops — `docker compose restart memcached`
  after DB-level style surgery, or you'll chase ghosts.
- Full container restart after config changes; `apachectl graceful` breaks
  (`modperl.pl` deletes itself from `%INC`).
- Case-insensitive filesystems: a bare `lj/` gitignore rule also matches
  `overlay/cgi-bin/LJ/`. It's anchored as `/lj/` — keep it that way.

## Quick verification

```bash
docker compose exec -T web bash -c 'mysql -h db -u lj -p"$DB_PASSWORD" livejournal -N -e \
  "SELECT COUNT(*) FROM ml_text; SELECT COUNT(*) FROM moods; SELECT COUNT(*) FROM log2;"'
# expect ~6753 ml_text rows and 132 moods on a fresh bootstrap
for p in / /login.bml /create.bml /update.bml /interface/flat; do
  curl -s -o /dev/null -w "$p = %{http_code}\n" "http://localhost:8080$p"; done
```

Posting via the flat protocol (the importer's mechanism) in three lines of
Python — see `import/load_local.py:post_entry`.
