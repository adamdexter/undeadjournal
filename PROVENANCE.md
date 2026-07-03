# Provenance, licensing & trademarks

This project is a preservation/homage effort. Here is exactly where every part
comes from and why the packaging works the way it does.

## The engine (GPL — redistributable, and we do)

- **Classic LiveJournal server**: fetched at Docker build time from
  [apparentlymart/livejournal](https://github.com/apparentlymart/livejournal),
  pinned to commit `7f92f9395323fca77b4061b5140011ae96b32d66` (January 2011 —
  the last state of the archive that is both *complete* and *mod_perl2-capable*).
  License: **GPL-2.0**. We do not vendor the tree; the Dockerfile clones it and
  applies compatibility patches (documented in [HACKING.md](HACKING.md)).
- **Transplanted subsystems**: the archive above is missing several files the
  engine needs (the BML page engine, the S2 compiler, `DBI::Role`, HTML/CSS
  cleaners, `moods.dat`). These were taken from
  [dreamwidth/dreamwidth](https://github.com/dreamwidth/dreamwidth) — the same
  LiveJournal code lineage, **GPL-2.0** — and live in `overlay/cgi-bin/` and
  `overlay/src/`.
- **Everything we wrote** (Dockerfile, patches, stubs, setup/backup/import
  scripts, the `.look` scheme markup, docs): **GPL-2.0**, same as the engine it
  derives from. See [LICENSE](LICENSE).

## The artwork (archival — bundled with a disclaimer)

The DeadJournal visual identity — the skull header/footer images, bone borders,
parchment backgrounds, `djstyle.css`, favicon, and nav icons — is the
copyrighted work of DeadJournal.com (design credit: **mindvamp**). The
"SK Cute Skulls" mood icons were drawn by their artist for the Dreamwidth
mood-theme collection.

So that this project remains a **self-contained time capsule** — usable even if
the archives it was recovered from ever disappear — those assets are bundled in
[`assets/authentic/`](assets/authentic/), together with a
[DISCLAIMER](assets/authentic/DISCLAIMER.md) stating their provenance
(public Wayback Machine captures, 2006–2013, and the public Dreamwidth
repository), their preservation/educational purpose, and a **prompt-takedown
promise**: any rights holder who wants them removed need only open an issue.

To be plain about the legal position: a disclaimer is not a license, and this
project claims none. The rights remain entirely with their owners. The bundle
exists for archival resilience; the project is engineered to survive without
it —

- `scripts/fetch-authentic-skin.sh` prefers the local bundle, and **falls back
  to downloading from the public archives** if `assets/authentic/` is absent
  (e.g., removed after a takedown request);
- `LJ_SCHEME=bluewhite` in `.env` runs the site with the stock
  classic-LiveJournal look and no DeadJournal artwork at all.

At install time the artwork is copied into `overlay/htdocs/` (those copies are
gitignored — `assets/authentic/` is the single tracked source).

## Names & trademarks

- "**LiveJournal**" is a trademark of its current owner. "**DeadJournal**" and
  the DeadJournal skull identity belong to DeadJournal.com / its operators.
- This project is **not affiliated with, endorsed by, or connected to** either
  site. Names are used nominatively — to describe what the software is and
  what it's compatible with.
- The default `SITE_NAME` is "DeadJournal" purely as an homage default for
  private personal installs; change it in `.env` to anything you like.
- DeadJournal.com is still online. If it matters to you, support it:
  <https://www.deadjournal.com/paidaccounts/>.

## The homepage text

The classic DeadJournal homepage prose is also copyrighted; the homepage in
this repo (`overlay/htdocs/index.bml`) uses original text in the same spirit,
with the same layout and the (uncopyrightable) short navigation labels. It's
your homepage — edit it.
