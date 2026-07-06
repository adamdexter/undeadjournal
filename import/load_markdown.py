#!/usr/bin/env python3
"""
Post a folder of Markdown notes into your LOCAL journal, using each file's
creation date (st_birthtime on macOS) as the entry date — the modern
successor to the old deadjournal.py that posted to the live site.

Built for Bear exports: each top-level "<title>.md" becomes one entry.
  * subject      = the filename without ".md" (the Bear note title)
  * event body   = the file's text, verbatim (UTF-8), like the old workflow
                   — the leading "# <title>" line is kept, matching the #dj
                   entries already in the journal
  * eventtime    = the file's creation date (st_birthtime), to the minute
  * security     = private by default (override with --security)
  * opt_backdated = 1 on every post, so historical notes land at their real
                   date instead of showing up as brand-new

It reuses load_local.py's flat-protocol posting (challenge/response auth,
the same /interface/flat endpoint), so behavior matches ./import-journal.

Notes exported by Bear as a FOLDER (a note that had image/audio attachments)
are handled two ways:
  * folder + a matching top-level "<title>.md"  -> the .md is posted (its
    text); the binary attachments are NOT embedded (the flat text protocol
    can't host them).
  * folder with NO matching .md (a note that was ONLY an image or voice memo)
    -> skipped, and listed at the end so you know what wasn't posted.

Python 3 standard library only. Interactive; run via ./import-markdown.

  ./import-markdown --dir "~/Documents/Bear export/DJ-2026"
  ./import-markdown --dir DIR --dry-run          # preview, post nothing
"""

import argparse
import getpass
import os
import sys
import time
import unicodedata
from datetime import datetime


def _key(name):
    """Normalize a filename for matching folders to .md stems: macOS stores
    names decomposed (NFD) and its default filesystem is case-insensitive, so
    a '#dj' folder and a '#DJ.md' text file are the same note."""
    return unicodedata.normalize("NFC", name).casefold()

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
# Reuse the tested flat-protocol poster from the JSON/XML importer.
from load_local import default_server, post_entry  # noqa: E402


def creation_time(path):
    """File creation date: st_birthtime on macOS, else mtime (matches the
    original deadjournal.py's getCreationTime)."""
    st = os.stat(path)
    ts = getattr(st, "st_birthtime", None)
    if ts is None:
        ts = st.st_mtime
    return datetime.fromtimestamp(int(ts))


def read_body(path):
    """Read a note as text. Defensively swap the old Windows smart-apostrophe
    byte (0x92) for a plain ' — harmless on clean UTF-8 Bear exports, and it
    rescues any legacy note that still carries it — then decode UTF-8."""
    with open(path, "rb") as fh:
        raw = fh.read()
    raw = raw.replace(b"\x92", b"'")
    return raw.decode("utf-8", errors="replace")


def collect(directory):
    """Return (entries, skipped_attachment_notes, text_notes_with_attachments).

    entries: dicts ready for post_entry, sorted oldest-first.
    """
    directory = os.path.abspath(os.path.expanduser(directory))
    if not os.path.isdir(directory):
        sys.exit(f"Not a directory: {directory}")

    md_stems = set()
    entries = []
    for name in os.listdir(directory):
        if not name.lower().endswith(".md"):
            continue
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            continue
        stem = name[:-3]
        md_stems.add(_key(stem))
        body = read_body(path).strip()
        if not body:
            continue  # empty note — nothing to post
        entries.append({
            "subject": stem,
            "event": body,
            "eventtime": creation_time(path).strftime("%Y-%m-%d %H:%M:%S"),
            "security": None,   # filled in by main() from --security
            "_stem": stem,
        })

    dir_keys = {_key(n): n for n in os.listdir(directory)
                if os.path.isdir(os.path.join(directory, n))}
    for e in entries:
        e["_hasdir"] = _key(e["_stem"]) in dir_keys

    # Attachment folders with NO matching .md text: a note that was only an
    # image or voice memo. Match case-insensitively (see _key).
    textless = []
    for key, name in dir_keys.items():
        if key not in md_stems:
            d = os.path.join(directory, name)
            n = sum(1 for f in os.listdir(d) if not f.startswith("."))
            textless.append((name, n))

    entries.sort(key=lambda e: e["eventtime"])   # oldest first
    with_attach = [e["subject"] for e in entries if e["_hasdir"]]
    return entries, sorted(textless), with_attach


def main():
    ap = argparse.ArgumentParser(description="Post a folder of Markdown notes into your local journal.")
    ap.add_argument("--dir", required=True, help="folder of .md notes (Bear export)")
    ap.add_argument("--user", default=os.environ.get("LJ_LOCAL_USER"))
    ap.add_argument("--password", default=os.environ.get("LJ_LOCAL_PASSWORD"))
    ap.add_argument("--server", default=default_server())
    ap.add_argument("--security", default="private",
                    choices=["private", "public", "usemask"],
                    help="security level for every post (default: private)")
    ap.add_argument("--sleep", type=float, default=0.5)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()
    interactive = sys.stdin.isatty()

    entries, textless, with_attach = collect(args.dir)
    for e in entries:
        e["security"] = args.security
    if args.limit:
        entries = entries[: args.limit]

    if not entries:
        sys.exit("No postable .md notes found.")

    print(f"[md] {len(entries)} notes from {os.path.abspath(os.path.expanduser(args.dir))}")
    print(f"[md] date range: {entries[0]['eventtime']}  ->  {entries[-1]['eventtime']}")
    print(f"[md] security: {args.security}")
    years = {}
    for e in entries:
        years[e["eventtime"][:4]] = years.get(e["eventtime"][:4], 0) + 1
    print("[md] by year: " + ", ".join(f"{y}:{years[y]}" for y in sorted(years)))
    if with_attach:
        print(f"[md] note: {len(with_attach)} of these also have image/audio "
              f"attachments that will NOT be embedded (text is posted).")
    if textless:
        print(f"[md] skipping {len(textless)} attachment-only notes (no text body):")
        for name, n in textless:
            print(f"       - {name}  ({n} attachment{'s' if n != 1 else ''})")

    if args.dry_run:
        print("\n[md] first entries:")
        for e in entries[:8]:
            print(f"  - {e['eventtime']}  [{e['security']}]  {e['subject'][:60]}")
        if len(entries) > 8:
            print(f"  ... and {len(entries) - 8} more")
        print("[md] dry run — nothing posted.")
        return

    if not args.user:
        if interactive:
            base = args.server.split("/interface")[0]
            args.user = input(f"Username of YOUR LOCAL account (on {base}): ").strip()
        if not args.user:
            ap.error("--user is required (or set LJ_LOCAL_USER)")
    password = args.password or getpass.getpass(f"Local password for {args.user}: ")

    if interactive:
        go = input(f"Post {len(entries)} {args.security} notes into '{args.user}'? [Y/n] ").strip().lower()
        if go not in ("", "y", "yes"):
            print("Cancelled — nothing posted.")
            return

    ok = failed = 0
    for i, entry in enumerate(entries, 1):
        try:
            # Always backdated: these are historical notes, so they should land
            # at their creation date, not jump to the top as new posts.
            res = post_entry(args.server, args.user, password, entry, backdate=True)
            if res.get("success") == "OK":
                ok += 1
                print(f"[md] {i}/{len(entries)} posted {entry['eventtime']}  {entry['subject'][:48]}")
            else:
                failed += 1
                print(f"[md] {i}/{len(entries)} FAILED {entry['eventtime']}: {res.get('errmsg')}",
                      file=sys.stderr)
        except Exception as exc:
            failed += 1
            print(f"[md] {i}/{len(entries)} ERROR {entry['eventtime']}: {exc}", file=sys.stderr)
        time.sleep(args.sleep)

    base = args.server.split("/interface")[0]
    print(f"\n[md] done. posted={ok} failed={failed}")
    print(f"[md] see your journal: {base}/users/{args.user}/  (and the calendar view)")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
