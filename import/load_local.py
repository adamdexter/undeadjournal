#!/usr/bin/env python3
"""
Import your exported journal entries into YOUR LOCAL instance, preserving the
original dates, so your history appears natively and you can keep posting.

Input (auto-detected, in this order):
  1. import/data/entries.json      — written by fetch_deadjournal.py (recommended)
  2. import/data/*.xml             — classic LiveJournal/DeadJournal month exports
                                     downloaded by hand from export.bml

It replays each entry through the LOCAL server's LiveJournal "flat" protocol
(/interface/flat, mode=postevent) using challenge/response auth. The protocol
allocates itemids, handles clustering/tags, etc. — much safer than raw SQL.

Why the flat protocol (not XML-RPC): this 2011 engine serves /interface/flat;
its XML-RPC endpoint isn't wired up. Flat is form-encoded and dependency-free.

Rules (verified against cgi-bin/ljprotocol.pl):
  * Entries are posted OLDEST FIRST (posting older-than-newest without
    opt_backdated fails with error 153; oldest-first avoids that and keeps
    history visible in both the recent view and the calendar).
  * On a 153/152 time conflict, that one entry is retried with opt_backdated=1.
  * Bodies are posted as UTF-8 with ver=1.

Python 3 standard library only. Run with no arguments for interactive mode:

  ./import-journal                        (from the repo root)
  python3 import/load_local.py --dry-run  (preview without posting)
"""

import argparse
import getpass
import glob
import hashlib
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_DIR = os.path.join(HERE, "data")
JSON_DEFAULT = os.path.join(DATA_DIR, "entries.json")

CARRY_PROPS = (
    "current_mood", "current_moodid", "current_music",
    "current_location", "current_coords",
    "taglist", "opt_preformatted", "picture_keyword",
)


def default_server():
    """Derive the local server URL from the repo's .env (HTTP_PORT), else :8080."""
    port = "8080"
    env_path = os.path.join(ROOT, ".env")
    if os.path.exists(env_path):
        try:
            with open(env_path, encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if line.startswith("HTTP_PORT="):
                        port = line.split("=", 1)[1].strip() or port
        except OSError:
            pass
    return f"http://localhost:{port}/interface/flat"


def md5_hex(s):
    return hashlib.md5(s.encode("utf-8")).hexdigest()


def flat_call(server, fields):
    """POST a flat-protocol request; return the response as a dict."""
    body = urllib.parse.urlencode(fields).encode("utf-8")
    req = urllib.request.Request(server, data=body)
    raw = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
    lines = raw.split("\n")
    out = {}
    for i in range(0, len(lines) - 1, 2):
        out[lines[i]] = lines[i + 1]
    return out


def split_eventtime(et):
    date_part, _, time_part = et.partition(" ")
    y, mo, d = (int(x) for x in date_part.split("-"))
    hh, mm = 0, 0
    if time_part:
        bits = time_part.split(":")
        hh = int(bits[0]); mm = int(bits[1]) if len(bits) > 1 else 0
    return y, mo, d, hh, mm


def load_xml_export(path):
    """Parse one classic LiveJournal/DeadJournal export.bml month XML file."""
    entries = []
    tree = ET.parse(path)
    for e in tree.getroot().iter("entry"):
        def text(tag, default=""):
            el = e.find(tag)
            return el.text if el is not None and el.text is not None else default
        props = {}
        for p in ("current_music", "current_mood", "current_moodid", "taglist",
                  "current_location", "picture_keyword"):
            v = text(p, None)
            if v:
                props[p] = v
        entries.append({
            "itemid": text("itemid", None),
            "eventtime": text("eventtime"),
            "subject": text("subject"),
            "event": text("event"),
            "security": text("security", "public") or "public",
            "allowmask": text("allowmask", 0) or 0,
            "props": props,
        })
    return entries


def load_entries(infile=None):
    """Find and load entries: explicit file, entries.json, or data/*.xml."""
    if infile:
        if infile.endswith(".xml"):
            return load_xml_export(infile), infile
        with open(infile, encoding="utf-8") as fh:
            return json.load(fh), infile
    if os.path.exists(JSON_DEFAULT):
        with open(JSON_DEFAULT, encoding="utf-8") as fh:
            return json.load(fh), JSON_DEFAULT
    xmls = sorted(glob.glob(os.path.join(DATA_DIR, "*.xml")))
    if xmls:
        all_entries = []
        for x in xmls:
            got = load_xml_export(x)
            print(f"[load] {os.path.basename(x)}: {len(got)} entries")
            all_entries.extend(got)
        return all_entries, f"{len(xmls)} XML file(s) in import/data/"
    return None, None


def post_entry(server, user, password, entry, backdate=False):
    ch = flat_call(server, {"mode": "getchallenge"})
    chal = ch.get("challenge")
    if not chal:
        raise RuntimeError("no challenge from server: %r" % ch)
    auth = md5_hex(chal + md5_hex(password))

    y, mo, d, hh, mm = split_eventtime(entry["eventtime"])
    f = {
        "mode": "postevent",
        "user": user,
        "auth_method": "challenge",
        "auth_challenge": chal,
        "auth_response": auth,
        "ver": "1",
        "lineendings": "unix",
        "year": y, "mon": mo, "day": d, "hour": hh, "min": mm,
        "subject": entry.get("subject", "") or "",
        "event": entry["event"],
        "security": entry.get("security", "public") or "public",
    }
    if f["security"] == "usemask":
        f["allowmask"] = int(entry.get("allowmask", 0) or 0)
    # entry properties are passed as prop_<name> in the flat protocol
    src = entry.get("props", {}) or {}
    for k in CARRY_PROPS:
        if k in src and src[k] not in (None, ""):
            f["prop_" + k] = src[k]
    if backdate:
        f["prop_opt_backdated"] = 1

    return flat_call(server, f)


def main():
    ap = argparse.ArgumentParser(description="Import entries into your local instance (flat protocol).")
    ap.add_argument("--user", default=os.environ.get("LJ_LOCAL_USER"))
    ap.add_argument("--password", default=os.environ.get("LJ_LOCAL_PASSWORD"))
    ap.add_argument("--server", default=default_server())
    ap.add_argument("--in", dest="infile", default=None,
                    help="entries.json or a single export.xml (default: auto-detect in import/data/)")
    ap.add_argument("--sleep", type=float, default=0.5)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()
    interactive = sys.stdin.isatty()

    entries, source = load_entries(args.infile)
    if entries is None:
        print("No exported entries found.")
        print(f"  Looked for: {JSON_DEFAULT}")
        print(f"         and: {os.path.join(DATA_DIR, '*.xml')}")
        print("Run ./export-journal first (or drop export.bml XML files into import/data/).")
        sys.exit(1)

    entries = [e for e in entries if e.get("eventtime") and e.get("event")]
    entries.sort(key=lambda e: e.get("eventtime") or "")   # oldest first
    if args.limit:
        entries = entries[: args.limit]
    print(f"[load] {len(entries)} entries from {source}")
    print(f"[load] oldest={entries[0]['eventtime'] if entries else '-'}, "
          f"newest={entries[-1]['eventtime'] if entries else '-'}")

    if args.dry_run:
        for e in entries[:5]:
            print(f"  - {e['eventtime']}  [{e.get('security','public')}]  {(e.get('subject') or '(no subject)')[:60]}")
        if len(entries) > 5:
            print(f"  ... and {len(entries) - 5} more")
        print("[load] dry run — nothing posted.")
        return

    if not args.user:
        if interactive:
            args.user = input(f"Username of YOUR LOCAL account (on {args.server.split('/interface')[0]}): ").strip()
        if not args.user:
            ap.error("--user is required (or set LJ_LOCAL_USER)")
    password = args.password or getpass.getpass(f"Local password for {args.user}: ")

    if interactive:
        go = input(f"Import {len(entries)} entries into '{args.user}'? [Y/n] ").strip().lower()
        if go not in ("", "y", "yes"):
            print("Cancelled — nothing imported.")
            return

    ok = backdated = failed = 0
    for i, entry in enumerate(entries, 1):
        try:
            res = post_entry(args.server, args.user, password, entry)
            if res.get("success") == "OK":
                ok += 1
                print(f"[load] {i}/{len(entries)} posted {entry['eventtime']} -> {res.get('url','')}")
            else:
                err = res.get("errmsg", "")
                if "153" in err or "152" in err or "backdate" in err.lower() or "time" in err.lower():
                    res = post_entry(args.server, args.user, password, entry, backdate=True)
                    if res.get("success") == "OK":
                        backdated += 1
                        print(f"[load] {i}/{len(entries)} posted (backdated) {entry['eventtime']}")
                    else:
                        failed += 1
                        print(f"[load] {i}/{len(entries)} FAILED {entry['eventtime']}: {res.get('errmsg')}", file=sys.stderr)
                else:
                    failed += 1
                    print(f"[load] {i}/{len(entries)} FAILED {entry['eventtime']}: {err}", file=sys.stderr)
        except Exception as e:
            failed += 1
            print(f"[load] {i}/{len(entries)} ERROR {entry['eventtime']}: {e}", file=sys.stderr)
        time.sleep(args.sleep)

    base = args.server.split("/interface")[0]
    print(f"\n[load] done. posted={ok} backdated={backdated} failed={failed}")
    print(f"[load] see your journal: {base}/users/{args.user}/  (and the calendar view)")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
