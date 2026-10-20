#!/usr/bin/env python3
"""Manage the add-ons on your Stremio account from your laptop; the TV app syncs them on sign-in.

    stremio-addons.py --list                         show the account's add-ons
    stremio-addons.py URL [URL ...]                  add add-ons by manifest URL
    stremio-addons.py --file examples/x/addons.txt   add every URL in a file (# comments ok)

Asks for your Stremio email and password (hidden) each run; nothing is stored. Uses the same
undocumented endpoints as Stremio's own client (github.com/Stremio/stremio-api-client).
"""
import getpass
import json
import sys
import urllib.request

API = "https://api.strem.io/api/"


def call(method, **params):
    req = urllib.request.Request(API + method, json.dumps(params).encode(),
                                 {"content-type": "application/json"})
    body = json.load(urllib.request.urlopen(req, timeout=30))
    if body.get("error"):
        sys.exit(f"{method} failed: {body['error']}")
    return body["result"]


def fetch_json(url):
    req = urllib.request.Request(url, headers={"user-agent": "tv-home"})
    return json.load(urllib.request.urlopen(req, timeout=30))


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    urls = []
    if a[0] == "--file":
        for line in open(a[1]):
            line = line.split("#", 1)[0].strip()
            if line:
                urls.append(line)
    elif a[0] != "--list":
        urls = a

    auth = call("login", email=input("Stremio email: "), password=getpass.getpass("Password: "))["authKey"]
    addons = call("addonCollectionGet", authKey=auth, update=True)["addons"]

    if a[0] == "--list":
        for x in addons:
            print(f"{x['manifest'].get('name', '?'):30} {x['transportUrl']}")
        return

    have = {x["transportUrl"] for x in addons}
    added = 0
    for url in urls:
        if url in have:
            print(f"already there: {url}")
            continue
        manifest = fetch_json(url)
        addons.append({"transportUrl": url, "manifest": manifest, "flags": {}})
        have.add(url)
        added += 1
        print(f"added: {manifest.get('name', url)}")
    if added:
        call("addonCollectionSet", authKey=auth, addons=addons)
    print(f"{len(addons)} add-ons on the account. Sign in on the TV (or reopen Stremio) to sync.")


if __name__ == "__main__":
    main()
