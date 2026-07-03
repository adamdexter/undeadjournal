# 🪦 UnDeadJournal

**Run your own DeadJournal.** This project resurrects the authentic, classic
[LiveJournal](https://github.com/apparentlymart/livejournal) server software —
the same code DeadJournal.com has run since the early 2000s — wrapped in Docker
so *anyone* can run it, styled exactly like DeadJournal circa 2003–2006, with a
one-command importer for your old journal.

Your entries. Your server. Nobody can shut it down, sell it, or train on it.

```
git clone https://github.com/adamdexter/undeadjournal
cd undeadjournal
./setup.sh
```

That's genuinely it. The setup wizard checks Docker, asks a few questions
(press Enter to accept the defaults), downloads the authentic gothic artwork,
builds the site, and helps you create your account. Ten minutes later you have
your own crypt at `http://localhost:8080`.

> ⚠️ **One rule: keep it private.** This is 20-year-old software run *on
> purpose* for authenticity — it is not safe to expose to the open internet.
> Run it on your own computer, your home network, or behind a VPN like
> [Tailscale](https://tailscale.com). See ["Putting it on a server"](#putting-it-on-a-server) below.

---

## 🖤 A note from the author

To be clear: as of this publishing, the **REAL** DeadJournal is still (un)alive
and well at [DeadJournal.com](https://www.deadjournal.com). This project was
created (1) out of nostalgia, for posterity, and (2) because I still use my
DeadJournal — but with the lightspeed progression of AI and every website
becoming a training ground, I no longer feel comfortable publishing content
newer than about seven years old to the open web. I still wanted the authentic
experience of writing in and visiting my journal — from the safety of my home
NAS server.

That said, I want to be clear and lead by example: **I am still a paid user on
DeadJournal.com.** If you find yourself here in this repo, you must really love
DeadJournal too — so let me remind you that the site runs purely on the
goodwill of its admins and the minimal money donated by paid users. Show your
support, show your love: [go upgrade to a paid
membership](https://www.deadjournal.com/paidaccounts/) if it feels right for you.

I did not create this repo as a way to off-board or steal users from the REAL
DeadJournal. I did this out of love for DeadJournal, and to share with neurotic
and nostalgic nerds like myself. And to put my money where my mouth is: this
project includes a nifty **optional plugin** —
[Astral Projection](plugins/astral-projection/) — that parallel-publishes
entries you write locally to your real DeadJournal.com account, so you can run
your private crypt *and* keep feeding the original. **Long (un)live
DeadJournal.com!**

*I have no affiliation with DeadJournal.com or Warped Inc., and I created this
project completely of my own accord.*

---

## What you get

- **The real thing** — not a lookalike. The actual classic LiveJournal Perl
  engine (pinned to its last complete open-source state), with the S1 style
  system, BML pages, moods, the flat & challenge/response protocols — the whole
  2003 experience.
- **The DeadJournal look — in your choice of era.** The skull header, bone
  borders, parchment body, "Enter the Crypt" / "Join the Undead" / "Random
  Grave" navigation, skull mood icons, dark gothic journals. (The archival
  artwork ships with the repo — a fully self-contained time capsule; see
  [PROVENANCE.md](PROVENANCE.md) and
  [assets/authentic/DISCLAIMER.md](assets/authentic/DISCLAIMER.md).)
  Setup asks which era you want — all three ship in every install, each
  faithful to Wayback captures:
  - **DeadJournal 2003** — the classic: the longest-standing design, arial
    12px, `userinfo.gif` bullets, the live stats line, *"Shaddap and gimme a
    GodDammed Deadjournal!"*
  - **DeadJournal 2015** — tombstone bullets, bigger type, the later (angrier)
    homepage copy, the "© Warped, Inc. — Get A Paid Account" footer
  - **DeadJournal 2025** — the 2015 design with the minimal responsive layout
    the real DJ shipped in 2025 (usable on your phone)

  Micro-tuner bonus: append `?usescheme=deadjournal2015` (or `deadjournal`,
  `deadjournal2025`) to any URL to time-travel instantly — no rebuild needed.
- **Your old journal, back** — export every entry from deadjournal.com (or any
  classic LiveJournal-based site) and import it with original dates, moods, and
  music intact.
- **Boring, reliable ops** — one command to back up, one to restore, survives
  reboots, keeps your data in a named Docker volume.
- **🔮 Astral Projection** (optional plugin) — parallel-publish entries you
  write locally to your **real DeadJournal.com** account, so your private crypt
  and the original both get your words. See
  [plugins/astral-projection/](plugins/astral-projection/).

## What you need

- A computer that can run [Docker](https://docs.docker.com/get-docker/)
  (Mac, Linux, Windows-with-WSL2, a home server, a Synology/QNAP NAS...).
  2 GB of RAM and a few GB of disk are plenty for a personal journal.
- Ten minutes.

No programming knowledge required. If you can install an app and copy-paste
three commands, you can run this.

---

## Quick start

1. **Install Docker Desktop** ([download](https://docs.docker.com/get-docker/)) and start it.
2. **Get this project** — either `git clone` it, or download the ZIP from GitHub
   and unzip it.
3. **Run the wizard** in a terminal:
   ```bash
   cd undeadjournal
   ./setup.sh
   ```
4. Open the address it prints (default `http://localhost:8080`), log in with
   the account it created for you, and click **Update Journal** to write your
   first entry.

To stop the site: `docker compose down` · To start it again: `docker compose up -d`
— your journal is kept either way.

---

## Bring your old DeadJournal home

Two commands, run from the project folder:

```bash
./export-journal     # downloads all your entries from deadjournal.com
./import-journal     # loads them into YOUR site, original dates preserved
```

Both are interactive — they ask for your username and password and walk you
through any hiccups (including deadjournal.com's Cloudflare check, which
requires copying one cookie from your browser; the script shows you exactly
how). Your password is used only for the login handshake (challenge/response —
it is never sent in plain text) and is not stored.

**Alternative (no scripts):** log into deadjournal.com, download each month
from `https://www.deadjournal.com/export.bml` as XML, drop the files into
`import/data/`, then run `./import-journal`.

Works for any classic LiveJournal-codebase site, not just DeadJournal:
`./export-journal --site https://www.livejournal.com` etc.

> **Do this soon.** DeadJournal has been running on borrowed time for two
> decades. Export your entries even if you never run this server.

---

## Daily use

| I want to... | Where |
|---|---|
| Write an entry | **Update Journal** (`/update.bml`) — moods, music, the works |
| Read my journal | `/users/YOURNAME/` |
| Edit old entries | `/editjournal.bml` |
| Change the look | `/customize/` (S1 styles, like 2003) |
| Add another person | send them to `/create.bml` ("Join the Undead") |
| Back up everything | `./backup.sh` → drops a dated file in `backups/` |
| Restore a backup | `./restore.sh backups/journal-....sql.gz` |

Accounts created via **Join the Undead** automatically get the gothic dark
journal style and skull mood icons.

---

## Putting it on a server

The same three commands work on any Linux box or NAS with Docker. During
`./setup.sh`, answer "**2**" to the network question so other devices can reach
it, and give it the address you'll use.

**Read this part carefully:**

- ✅ **Home network**: fine as-is. Your journal is reachable from your devices,
  invisible to the internet.
- ✅ **Private remote access**: install [Tailscale](https://tailscale.com) (free
  for personal use) on the server and your devices — you can reach your journal
  from anywhere, and it stays completely off the public internet. **This is the
  recommended way.**
- ⚠️ **Public internet (VPS with a domain)**: strongly discouraged — this
  codebase stopped receiving security fixes over a decade ago. If you truly
  need it public, at minimum put it behind the included Caddy proxy with HTTPS
  **and a password on the whole site**:
  ```bash
  cp caddy/Caddyfile.example caddy/Caddyfile   # edit domain + password hash
  docker compose -f docker-compose.yml -f docker-compose.public.yml up -d
  ```
  Everyone will need the extra password before they even see the site. You are
  accepting real risk; keep backups.

---

## Troubleshooting

**The build fails.** Usually a flaky package download (the base OS images come
from archive.debian.org, which has slow days). Just run `./setup.sh` again — it
resumes. Still stuck? `docker compose logs web` and open a GitHub issue with
the last 30 lines.

**The site shows the wrong look / plain look.** The artwork probably wasn't
installed. Run `scripts/fetch-authentic-skin.sh` (it copies from the bundled
`assets/authentic/` archive), make sure `.env` says `LJ_SCHEME=deadjournal`,
then `docker compose build web && docker compose up -d`.

**Export gets blocked (HTTP 403).** That's Cloudflare on deadjournal.com. Run
`./export-journal` and follow the on-screen steps (open the site in your
browser, copy the `cf_clearance` cookie value when asked).

**I forgot my journal password.** Log in as `system` (password is
`SYSTEM_PASSWORD` in your `.env` file) and use the admin console, or create a
new account and re-import.

**Something else.** `docker compose logs web` is where the truth lives. For
engine internals, see [HACKING.md](HACKING.md).

---

## FAQ

**Is this legal?** The LiveJournal server code is GPL open source — running and
sharing it is exactly what the license is for. The DeadJournal *artwork* is
copyrighted by its owners; it's bundled here purely as a preservation archive
(sourced from public Wayback Machine captures), with a clear disclaimer and a
prompt-takedown promise to the rights holders — and the project runs fine
without it. Full story: [PROVENANCE.md](PROVENANCE.md) and
[assets/authentic/DISCLAIMER.md](assets/authentic/DISCLAIMER.md).

**Is this affiliated with DeadJournal.com?** No. It's an independent
preservation/homage project. DeadJournal.com is still alive — if you love it,
[buy a paid account](https://www.deadjournal.com/paidaccounts/) and keep the
original running too.

**Comments? Communities? Userpics?** The engine supports them but this package
focuses on the core journaling loop (write, read, import). They're
partially wired; contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

**Why not just use Dreamwidth?** [Dreamwidth](https://www.dreamwidth.org) is
the actively-maintained descendant of this codebase and a great choice. This
project is for people who want the *2003 experience* — S1 styles, BML pages,
the DeadJournal look — running under their own control.

---

## Credits

- **Engine**: [apparentlymart/livejournal](https://github.com/apparentlymart/livejournal)
  (GPL) — the community archive of the classic LiveJournal server, by Danga
  Interactive / Brad Fitzpatrick and hundreds of contributors.
- **Missing-subsystem transplants**: [Dreamwidth](https://github.com/dreamwidth/dreamwidth) (GPL).
- **DeadJournal** and its look are the work of the DeadJournal.com team
  (design credit: mindvamp) — this project exists out of love for it.
- Revival engineering: built with a lot of stubbornness and
  [Claude](https://claude.com). See [HACKING.md](HACKING.md) for the full
  technical story of what it took.

License: [GPL-2.0](LICENSE) · Provenance & trademarks: [PROVENANCE.md](PROVENANCE.md)
