# Contributing

Delighted you're here. This is a preservation project — the bar is "keep the
2003 experience authentic, and keep `./setup.sh` idiot-proof."

## Ground rules

1. **The archival artwork lives in `assets/authentic/` and ONLY there.** That
   folder ships with its provenance disclaimer and takedown promise
   ([assets/authentic/DISCLAIMER.md](assets/authentic/DISCLAIMER.md)); the
   installed copies under `overlay/htdocs/` are gitignored. Don't scatter
   copyrighted media anywhere else in the repo, and don't add new copyrighted
   assets without the same provenance treatment. See [PROVENANCE.md](PROVENANCE.md).
2. **Read [HACKING.md](HACKING.md) before touching the engine.** Every patch in
   `web/Dockerfile` exists because something breaks without it; each is
   documented with its failure symptom.
3. **Test the golden path** before opening a PR:
   ```bash
   docker compose down -v        # wipe (test DB only!)
   ./setup.sh --defaults         # must complete without questions
   # then: create an account at /create.bml, post at /update.bml,
   # and confirm the entry renders at /users/<name>/
   ```
4. Keep `setup.sh` / `export-journal` / `import-journal` friendly to
   non-technical users: interactive prompts, plain-language errors, no new
   dependencies beyond Docker + Python 3 stdlib + curl/bash.

## Wanted (good first projects)

- Comments and communities end-to-end (the engine supports them; they're
  untested/partially stubbed here).
- Userpics (currently DB-blob storage path is wired but the upload UI is untested).
- An S2 story: the S2 layer compiler crashes `populate_s2()` against MariaDB
  ("MySQL server has gone away") — fixing that properly would unlock S2 styles.
- More classic mood themes / a way to pick a theme at setup.
- Windows-native setup script (`setup.ps1`).
- Import from other formats (ljdump, XML-RPC getevents dumps, Dreamwidth exports).

## Style

Match what's around you. Shell scripts are `bash` (macOS 3.2-compatible: no
associative arrays), Python is stdlib-only, Perl patches follow the upstream's
own conventions. Commit messages explain the *why*, not just the what.
