# 🔮 Astral Projection

*Write in the crypt; echo into the living world.*

An **optional plugin** that parallel-publishes entries you write on your local
UnDeadJournal to your account on the **real DeadJournal.com** (or any classic
LiveJournal-protocol site). Your local site stays the private archive; the real
DJ keeps getting your words. Long (un)live DeadJournal.com.

## Install

```bash
plugins/astral-projection/install.sh
docker compose build web && docker compose up -d
```

Log in, then look at the sidebar: under **RIP <your name>**, after
**Resurrection**, there's now **Astral Projection**. Open it, enter your
DeadJournal.com username and password, tick **enable**, and hit *Project...* —
it verifies your credentials against the remote site on the spot.

From then on, every entry you post locally (moods, music, tags, security level
included) is also posted to your real journal. The config page shows the result
of the last projection.

## Good to know

- **Your remote password is never stored.** Only its MD5 digest is saved —
  which is all the classic challenge/response login needs.
- **Failures can't hurt you.** If deadjournal.com is down/unreachable, your
  local entry posts normally and the failure is noted on the config page.
- **Bulk imports will NOT be projected.** Backdated entries and entries whose
  date is more than 48 hours from now are skipped automatically, so running
  `./import-journal` with Astral enabled won't flood the real site.
- **Community posts are not projected** — only entries in your own journal.
- **Cloudflare**: deadjournal.com sits behind Cloudflare. The protocol
  endpoints normally pass, but if projections fail with HTTP 403, paste a
  `cf_clearance=...` cookie + your browser's User-Agent into the "fine print"
  fields on the config page (same trick as `./export-journal`).
- Security levels carry over (public/friends/private). Friends-only entries
  map to your *remote* friends list, which may differ from your local one.

## Uninstall

```bash
plugins/astral-projection/uninstall.sh
docker compose build web && docker compose up -d
```

## How it works (for the curious)

The engine fires a `postpost` hook after every successful local post.
`LJ::AstralProjection` (loaded via `cgi-bin/ljlib-local.pl`) listens on it and
re-posts the entry over the LiveJournal **flat protocol** with
challenge/response auth (`getchallenge` → `postevent`). Settings live in
userprops (`astral_*`), registered automatically. ~200 lines of Perl, all of it
eval-guarded so the local posting path can never be broken by the remote side.
