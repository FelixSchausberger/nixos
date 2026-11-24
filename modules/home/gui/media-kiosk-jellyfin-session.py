#!/usr/bin/env python3
"""Seed the Zen kiosk profile with a Jellyfin web session.

The Jellyfin web client keeps its session in localStorage and offers no cookie
or URL authentication. The kiosk cannot type a password, so this runs before
the browser starts: it logs in with the credentials the system module renders
into the sops environment file and writes the same jellyfin_credentials record
a manual login stores. The profile lives on the persistence dataset, so the
row survives reboots and deploys, and the login repeats on every start so a
rotated password or a wiped profile heals itself.

Usage: media-kiosk-jellyfin-session <jellyfin-url> <env-file>
"""

import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Firefox encodes the storage origin as scheme+++host+port; the port matches
# the module's fixed jellyfinPort.
ORIGIN = "http://127.0.0.1:8096"
STORAGE = Path("storage/default/http+++127.0.0.1+8096/ls/data.sqlite")

# The storage schema Firefox creates for a localStorage origin.
SCHEMA = """
CREATE TABLE IF NOT EXISTS database(
  origin TEXT NOT NULL,
  usage INTEGER NOT NULL DEFAULT 0,
  last_vacuum_time INTEGER NOT NULL DEFAULT 0,
  last_analyze_time INTEGER NOT NULL DEFAULT 0,
  last_vacuum_size INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS data(
  key TEXT PRIMARY KEY,
  utf16_length INTEGER NOT NULL,
  conversion_type INTEGER NOT NULL,
  compression_type INTEGER NOT NULL,
  last_access_time INTEGER NOT NULL DEFAULT 0,
  value BLOB NOT NULL
);
"""


def log(message):
    print(f"media-kiosk-jellyfin-session: {message}", file=sys.stderr, flush=True)


def read_env(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        key, separator, value = line.partition("=")
        if separator and key.strip() and not key.lstrip().startswith("#"):
            values[key.strip()] = value.strip()
    return values


def request_json(url, body=None, headers=None, timeout=10):
    data = json.dumps(body).encode() if body is not None else None
    head = {"Accept": "application/json"}
    if headers:
        head.update(headers)
    if data is not None:
        head["Content-Type"] = "application/json"
    request = urllib.request.Request(
        url,
        data=data,
        headers=head,
        method="POST" if data is not None else "GET",
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=timeout) as response:
            payload = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:200]
        raise RuntimeError(f"HTTP {error.code} from {url}: {detail}") from error
    return json.loads(payload) if payload else {}


def read_device_id(database):
    """Reuse the browser's device id so the login lands on its own session."""
    try:
        connection = sqlite3.connect(database)
        row = connection.execute(
            "select value from data where key='_deviceId2'"
        ).fetchone()
        connection.close()
    except sqlite3.Error:
        return f"kiosk-{int(time.time() * 1000)}"
    if row and row[0]:
        return row[0].decode(errors="replace")
    return f"kiosk-{int(time.time() * 1000)}"


def login(base, user, password, device):
    return request_json(
        f"{base}/Users/AuthenticateByName",
        body={"Username": user, "Pw": password},
        headers={
            "Authorization": (
                f'MediaBrowser Client="kiosk", Device="m920q", '
                f'DeviceId="{device}", Version="1"'
            )
        },
    )


def seed(database, payload):
    database.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(database)
    connection.executescript(SCHEMA)
    connection.execute("INSERT OR IGNORE INTO database(origin) VALUES (?)", (ORIGIN,))
    text = json.dumps(payload, separators=(",", ":"))
    connection.execute(
        "INSERT OR REPLACE INTO data("
        "key, utf16_length, conversion_type, compression_type, last_access_time, value"
        ") VALUES (?, ?, 1, 0, 0, ?)",
        ("jellyfin_credentials", len(text.encode("utf-16-le")) // 2, text.encode()),
    )
    connection.commit()
    connection.close()


def main():
    if len(sys.argv) != 3:
        log("usage: media-kiosk-jellyfin-session <jellyfin-url> <env-file>")
        return 2

    base = sys.argv[1].rstrip("/")
    env = read_env(sys.argv[2])
    user = env.get("JELLYFIN_USER", "")
    password = env.get("JELLYFIN_PASSWORD", "")
    if not user or not password:
        log("JELLYFIN_USER/JELLYFIN_PASSWORD missing; leaving the profile untouched")
        return 0

    profile = Path(os.environ["HOME"]) / ".config/zen/kiosk"
    database = profile / STORAGE
    session = login(base, user, password, read_device_id(database))
    token = session.get("AccessToken") or ""
    user_id = (session.get("User") or {}).get("Id") or ""
    if not token or not user_id:
        log("Jellyfin login returned no access token")
        return 1

    info = request_json(f"{base}/System/Info/Public")
    seed(
        database,
        {
            "Servers": [
                {
                    "DateLastAccessed": int(time.time() * 1000),
                    "LastConnectionMode": 2,
                    "ManualAddress": base,
                    "manualAddressOnly": True,
                    "Name": info.get("ServerName") or "Jellyfin",
                    "Id": info.get("Id") or "",
                    "LocalAddress": base,
                    "AccessToken": token,
                    "UserId": user_id,
                }
            ]
        },
    )
    log(f"stored a Jellyfin web session for {user}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        # A missing browser session only degrades to the login page; it must
        # not keep the browser unit from starting.
        log(f"login failed: {error}")
        sys.exit(0)
