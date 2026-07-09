# CLAUDE.md — agent orientation

**UnDeadJournal** packages the authentic ~2003-era DeadJournal / classic
LiveJournal Perl engine under Docker, reskinned to the classic gothic look, for
**private** (localhost / LAN / Tailscale) self-hosting. It is deliberately
unpatched legacy software — never expose it to the public internet without the
Caddy password gate (see README "Putting it on a server").

## 🚨 Golden rule: this is a PUBLIC repo — never commit personal data

Journal entries, exported data, passwords, real names, emails, or a user's
private file paths must **never** be committed. `.env`, `import/data/`, and
`backups/` are gitignored — keep them that way. When adding examples, use
generic placeholders (`path/to/notes`, `you@example.com`), not real values.
Before any commit, sanity-check the diff for secrets/personal content.

## Architecture (one paragraph)

Three Docker services: **web** (Apache2 + mod_perl2 + the LiveJournal Perl tree,
built from a pinned upstream commit), **db** (MariaDB 10.6 forced into a
latin1 / permissive-`sql_mode` environment the old code needs — the schema
stores UTF-8 bytes in latin1 columns), **memcached**. The engine source is
fetched at build time and **patched in `web/Dockerfile`** (compat fixes for
modern Perl/MySQL/Apache); site-specific files are merged from **`overlay/`**.
Full engine internals, every patch with its symptom, and debugging traps are in
**`HACKING.md`** — read it before touching the engine.

## Build / run / test

```bash
./setup.sh                     # interactive: writes .env, builds, starts, first account
docker compose build web && docker compose up -d   # after an overlay/Dockerfile change
docker compose logs web        # where the truth lives
docker compose restart memcached   # ALWAYS after DB-level changes (it caches styles/props)
```
Verification recipes: `HACKING.md` ("Quick verification"). Site serves at
`http://localhost:${HTTP_PORT:-8080}/`.

## Working on the engine — the discipline that keeps it building

- **`web/Dockerfile` `sed` patches:** anchor against the file **inside the
  image** (`docker exec … sed -n 'N,Mp' file`), not a local checkout — engine
  snapshots differ in whitespace/line-numbers. Pair every `sed` with a `grep -q`
  guard so a missed anchor **fails the build** instead of silently no-opping.
- **Full container restart** after config changes — `apachectl graceful` breaks
  (`modperl.pl` removes itself from `%INC`).
- Wide chars in Perl that `print`s → "Wide character" 500s: use HTML entities.
  BML error-log lines contain literal `\n` — unescape when reading.
- Styles: **S1** (`/styles/`) and **S2** (`/customize/`, e.g. Generator) both
  work; system styles populate at first bootstrap. Site chrome is a BML `.look`
  scheme (`overlay/cgi-bin/bml/scheme/*.look`); era via `LJ_SCHEME`
  (deadjournal / deadjournal2015 / deadjournal2025 / bluewhite).

## Repo map

- `web/Dockerfile` — build + all compat patches. **Read first.**
- `overlay/` — everything merged onto the engine (config, `.look` schemes, skin,
  harvested modules, stubs). `assets/authentic/` — the tracked artwork bundle.
- `import/` — `export-journal`/`import-journal`/`import-markdown` tooling.
- `plugins/astral-projection/` — optional crosspost-to-DeadJournal plugin.
- Docs: this file → `README.md` (users) → `HACKING.md` (engine) →
  `PROVENANCE.md` (licensing) → `CONTRIBUTING.md`.
