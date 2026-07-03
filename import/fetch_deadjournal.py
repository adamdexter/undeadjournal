#!/usr/bin/env python3
"""
Fetch YOUR OWN DeadJournal entries (entries only — no comments) and save them
locally for import into your private instance.

DeadJournal runs the classic LiveJournal codebase, so it speaks the LiveJournal
XML-RPC protocol. This script:
  * authenticates with the challenge/response scheme (your password is never sent
    in the clear),
  * pages backward through every entry with getevents(selecttype='lastn') +
    beforedate,
  * writes them to import/data/entries.json.

Python 3 standard library only — nothing to pip install.

CLOUDFLARE: www.deadjournal.com sits behind a Cloudflare "Just a moment..."
JavaScript challenge. A plain script may get HTTP 403. If so:
  1. Open the site in a normal desktop browser and let the challenge clear.
  2. From the browser dev-tools, copy the cf_clearance cookie and your exact
     User-Agent string.
  3. Re-run with:  --cookie "cf_clearance=VALUE"  --user-agent "MOZILLA-STRING..."
Run this from your own machine/network (not the headless NAS).

Usage:
  python3 fetch_deadjournal.py --user YOURNAME [--password ... | will prompt]
  python3 fetch_deadjournal.py --user YOURNAME --cookie "cf_clearance=..." \
      --user-agent "Mozilla/5.0 (Macintosh; ...) ... Safari/537.36"
"""

import argparse
import getpass
import hashlib
import json
import os
import sys
import time
import xmlrpc.client

DEFAULT_SERVER = "https://www.deadjournal.com/interface/xmlrpc"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DEFAULT = os.path.join(HERE, "data", "entries.json")


def md5_hex(s):
    return hashlib.md5(s.encode("utf-8")).hexdigest()


class HeaderTransport(xmlrpc.client.SafeTransport):
    """SafeTransport that injects a custom User-Agent and Cookie header so we can
    ride a browser's cleared-Cloudflare session."""

    def __init__(self, user_agent=None, cookie=None):
        super().__init__()
        if user_agent:
            self.user_agent = user_agent
        self._cookie = cookie

    def send_headers(self, connection, headers):
        super().send_headers(connection, headers)
        if self._cookie:
            connection.putheader("Cookie", self._cookie)


def make_proxy(server, user_agent, cookie):
    transport = HeaderTransport(user_agent=user_agent, cookie=cookie)
    return xmlrpc.client.ServerProxy(server, transport=transport, use_datetime=False)


def get_challenge_auth(proxy, user, password):
    """Return the auth fields for a single request (challenges are single-use)."""
    ch = proxy.LJ.XMLRPC.getchallenge()
    challenge = ch["challenge"]
    response = md5_hex(challenge + md5_hex(password))
    return {
        "username": user,
        "auth_method": "challenge",
        "auth_challenge": challenge,
        "auth_response": response,
        "ver": 1,
    }


def decode_event(value):
    """getevents 'event' may be a plain string or an xmlrpc base64 Binary."""
    if isinstance(value, xmlrpc.client.Binary):
        return value.data.decode("utf-8", "replace")
    return value if isinstance(value, str) else str(value)


def normalize(ev):
    props = ev.get("props", {}) or {}
    clean_props = {}
    for k, v in props.items():
        if isinstance(v, xmlrpc.client.Binary):
            v = v.data.decode("utf-8", "replace")
        clean_props[k] = v
    return {
        "itemid": ev.get("itemid"),
        "eventtime": ev.get("eventtime"),
        "subject": decode_event(ev.get("subject", "")) if ev.get("subject") else "",
        "event": decode_event(ev.get("event", "")),
        "security": ev.get("security", "public"),
        "allowmask": ev.get("allowmask", 0),
        "url": ev.get("url", ""),
        "props": clean_props,
    }


def main():
    ap = argparse.ArgumentParser(description="Export your DeadJournal entries.")
    ap.add_argument("--user", default=os.environ.get("DJ_USER"),
                    help="your DeadJournal username")
    ap.add_argument("--password", default=os.environ.get("DJ_PASSWORD"),
                    help="your DeadJournal password (will prompt if omitted)")
    ap.add_argument("--site", default=None,
                    help="journal site base URL (e.g. https://www.livejournal.com) — "
                         "for exporting from other classic-LiveJournal sites")
    ap.add_argument("--server", default=DEFAULT_SERVER,
                    help="XML-RPC endpoint (default: live DeadJournal)")
    ap.add_argument("--journal", default=None,
                    help="usejournal (e.g. a community you own); default = your own journal")
    ap.add_argument("--cookie", default=os.environ.get("DJ_COOKIE"),
                    help='Cookie header, e.g. "cf_clearance=..." to pass Cloudflare')
    ap.add_argument("--user-agent", default=os.environ.get("DJ_UA"),
                    help="User-Agent to match your cleared browser session")
    ap.add_argument("--out", default=OUT_DEFAULT, help="output JSON path")
    ap.add_argument("--sleep", type=float, default=1.0,
                    help="seconds between requests (be gentle; default 1.0)")
    args = ap.parse_args()

    interactive = sys.stdin.isatty()
    if args.site:
        args.server = args.site.rstrip("/") + "/interface/xmlrpc"
    if not args.user:
        if interactive:
            args.user = input("Your DeadJournal username: ").strip()
        if not args.user:
            ap.error("--user is required (or set DJ_USER)")
    password = args.password or getpass.getpass(f"DeadJournal password for {args.user}: ")

    proxy = make_proxy(args.server, args.user_agent, args.cookie)

    print(f"[fetch] connecting to {args.server} as {args.user} ...")
    entries = {}
    beforedate = None
    page = 0
    cf_retries = 0
    try:
        while True:
            page += 1
            try:
                req = get_challenge_auth(proxy, args.user, password)
                req.update({
                    "selecttype": "lastn",
                    "howmany": 50,
                    "lineendings": "unix",
                    "ver": 1,
                })
                if args.journal:
                    req["usejournal"] = args.journal
                if beforedate:
                    req["beforedate"] = beforedate
                res = proxy.LJ.XMLRPC.getevents(req)
            except Exception as e:
                # Cloudflare block? Walk the user through fixing it, then retry
                # from the same place (nothing is lost).
                if "403" in str(e) and interactive and cf_retries < 3:
                    cf_retries += 1
                    page -= 1
                    print("\nCloudflare blocked the request. To get past it:")
                    print("  1. Open https://www.deadjournal.com/ in your normal browser and log in.")
                    print("  2. Open developer tools (F12) -> Application/Storage -> Cookies,")
                    print("     find 'cf_clearance' and copy its VALUE.")
                    print("  3. Also copy your browser's User-Agent (type 'navigator.userAgent'")
                    print("     in the dev-tools Console).")
                    cookie_val = input("Paste the cf_clearance value here: ").strip()
                    ua = input("Paste your browser User-Agent here: ").strip()
                    if cookie_val:
                        args.cookie = "cf_clearance=" + cookie_val.replace("cf_clearance=", "")
                    if ua:
                        args.user_agent = ua
                    proxy = make_proxy(args.server, args.user_agent, args.cookie)
                    print("[fetch] retrying...")
                    continue
                raise

            evs = res.get("events", []) or []
            new = 0
            earliest = None
            for ev in evs:
                norm = normalize(ev)
                iid = norm["itemid"]
                if iid not in entries:
                    entries[iid] = norm
                    new += 1
                et = norm["eventtime"]
                if et and (earliest is None or et < earliest):
                    earliest = et

            print(f"[fetch] page {page}: {len(evs)} returned, {new} new "
                  f"(total {len(entries)}), earliest={earliest}")

            if not evs or new == 0 or not earliest:
                break
            beforedate = earliest
            time.sleep(args.sleep)
    except xmlrpc.client.Fault as f:
        print(f"\n[fetch] XML-RPC fault {f.faultCode}: {f.faultString}", file=sys.stderr)
        if not entries:
            sys.exit(1)
        print("[fetch] saving what was retrieved before the fault.", file=sys.stderr)
    except Exception as e:
        print(f"\n[fetch] ERROR: {e}", file=sys.stderr)
        if "403" in str(e):
            print("[fetch] Cloudflare blocked the request. Re-run and follow the "
                  "interactive steps, or pass --cookie \"cf_clearance=...\" and "
                  "--user-agent matching your browser (see this script's header).",
                  file=sys.stderr)
        if not entries:
            sys.exit(1)

    out = sorted(entries.values(), key=lambda e: e["eventtime"] or "")
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2)
    print(f"\n[fetch] saved {len(out)} entries to {args.out}")
    print("[fetch] Verify this count against your live journal before trusting it.")


if __name__ == "__main__":
    main()
