#!/usr/bin/env python3
"""Sync Nextcloud calendar events into Grafana annotations.

Fetches the user's default personal calendar (CalDAV ICS export with basic
auth), converts VEVENTs into Grafana annotations tagged "calendar", and
posts only events not yet present (Grafana dedupes annotations through its
tags + time-window query: we probe for an existing annotation with the same
event uid tag before posting).

Secrets arrive through a sops-rendered EnvironmentFile:
  NC_URL            e.g. http://127.0.0.1:8081
  NC_USER           Nextcloud login name
  NC_APP_PASSWORD   app password (Settings -> Security -> Devices & sessions)
  GRAFANA_URL       e.g. http://127.0.0.1:3001
  GRAFANA_TOKEN     Grafana service-account token (Annotation Writer)
"""

import base64
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

from icalendar import Calendar

WINDOW_DAYS_BACK = 30
WINDOW_DAYS_FORWARD = 400
ANNOTATION_TAG = "calendar"


def fail(msg: str) -> "NoReturn":  # noqa: F821
    print(f"garmin-calendar-sync: {msg}", file=sys.stderr)
    raise SystemExit(1)


def env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        fail(f"missing environment variable {name}")
    return value


def http_request(
    url: str,
    *,
    auth: tuple[str, str] | None = None,
    headers: dict | None = None,
    data: bytes | None = None,
    method: str = "GET",
):
    req = urllib.request.Request(url, data=data, method=method)
    for key, value in (headers or {}).items():
        req.add_header(key, value)
    if auth:
        token = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
        req.add_header("Authorization", f"Basic {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as err:
        return err.code, err.read()
    except urllib.error.URLError as err:
        fail(f"connection failed for {url}: {err}")


def fetch_calendar_ics(nc_url: str, user: str, app_password: str) -> str:
    """Download the user's default personal calendar as ICS.

    Nextcloud's CalDAV export endpoint:
      {base}/remote.php/dav/calendars/{user}/personal/?export
    """
    base = nc_url.rstrip("/")
    quoted_user = urllib.parse.quote(user)
    url = f"{base}/remote.php/dav/calendars/{quoted_user}/personal/?export"
    status, body = http_request(url, auth=(user, app_password))
    if status != 200:
        fail(f"calendar export returned HTTP {status}: {body[:200]!r}")
    return body.decode("utf-8", errors="replace")



def parse_events(ics_text: str) -> list[dict]:
    """Extract concrete (non-recurring) and recurring-expanded events.

    The icalendar library does not expand RRULEs; recurring events are
    converted with their RRULE intact into a bounded series using
    dateutil (a transitive dependency of icalendar) so recurring
    appointments still mark the right days on the dashboard.
    """
    calendar = Calendar.from_ical(ics_text)
    now = datetime.now(timezone.utc)
    lo = now - timedelta(days=WINDOW_DAYS_BACK)
    hi = now + timedelta(days=WINDOW_DAYS_FORWARD)

    events = []
    for component in calendar.walk("VEVENT"):
        uid = str(component.get("UID", "")).strip()
        summary = str(component.get("SUMMARY", "(untitled)"))
        start = component.get("DTSTART")
        if start is None or uid == "":
            continue
        start_dt = start.dt
        if isinstance(start_dt, datetime):
            if start_dt.tzinfo is None:
                start_dt = start_dt.replace(tzinfo=timezone.utc)
        else:
            # All-day event: interpret at local midnight (floating).
            start_dt = datetime(
                start_dt.year, start_dt.month, start_dt.day, tzinfo=timezone.utc
            )

        end = component.get("DTEND")
        end_dt = None
        if end is not None:
            end_dt = end.dt
            if not isinstance(end_dt, datetime):
                end_dt = datetime(
                    end_dt.year, end_dt.month, end_dt.day, tzinfo=timezone.utc
                )
            elif end_dt.tzinfo is None:
                end_dt = end_dt.replace(tzinfo=timezone.utc)

        rrule = component.get("RRULE")
        occurrences = []
        if rrule is None:
            occurrences = [start_dt]
        else:
            try:
                from dateutil.rrule import rrulestr

                # rrulestr needs a naive or aware dt consistent with the rule.
                rule = rrulestr(rrule.to_ical().decode(), dtstart=start_dt)
                occurrences = list(rule.between(lo, hi, inc=True))
            except Exception as err:  # noqa: BLE001
                print(
                    f"garmin-calendar-sync: RRULE parse failed for {uid}: {err}",
                    file=sys.stderr,
                )
                occurrences = [start_dt]

        # Duration of the series base event (ms); constant across occurrences.
        duration_ms = None
        if end_dt is not None:
            seconds = (end_dt - start_dt).total_seconds()
            if seconds > 0:
                duration_ms = int(seconds * 1000)

        for occurrence in occurrences:
            if not (lo <= occurrence <= hi):
                continue
            events.append(
                {
                    "uid": uid,
                    "summary": summary,
                    # Grafana annotation timestamps are epoch milliseconds.
                    "time": int(occurrence.timestamp() * 1000),
                    "duration": duration_ms,
                    "all_day": not isinstance(component.get("DTSTART").dt, datetime),
                }
            )
    return events


def post_annotations(grafana_url: str, token: str, events: list[dict]) -> tuple[int, int]:
    """Post events as annotations; skip ones already synced (probed by uid tag)."""
    base = grafana_url.rstrip("/")
    posted = skipped = 0
    for event in events:
        uid_tag = f"event:{event['uid']}"
        # Dedupe probe: an annotation for this calendar occurrence already
        # exists if any annotation carries the exact event-uid tag.
        probe = f"{base}/api/annotations?tags={ANNOTATION_TAG}&tags={urllib.parse.quote(uid_tag)}&limit=1"
        status, body = http_request(probe, headers={"Authorization": f"Bearer {token}"})
        if status == 200:
            if json_len(body) > 0:
                skipped += 1
                continue
        else:
            print(
                f"garmin-calendar-sync: probe HTTP {status} for {uid_tag}",
                file=sys.stderr,
            )

        payload = {
            "time": event["time"],
            "tags": [ANNOTATION_TAG, uid_tag],
            "text": event["summary"],
        }
        if event["duration"]:
            payload["timeEnd"] = event["time"] + int(event["duration"])
        if event["all_day"]:
            payload["text"] = f"{event['summary']} (all-day)"

        status, body = http_request(
            f"{base}/api/annotations",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            data=json_bytes(payload),
            method="POST",
        )
        if status == 200:
            posted += 1
        else:
            print(
                f"garmin-calendar-sync: POST HTTP {status} for {uid_tag}: {body[:200]!r}",
                file=sys.stderr,
            )
    return posted, skipped


def json_len(body: bytes) -> int:
    import json

    try:
        return len(json.loads(body))
    except Exception:  # noqa: BLE001
        return 0


def json_bytes(payload: dict) -> bytes:
    import json

    return json.dumps(payload).encode()


def main() -> None:
    nc_url = env("NC_URL")
    nc_user = env("NC_USER")
    nc_app_password = env("NC_APP_PASSWORD")
    grafana_url = env("GRAFANA_URL")
    grafana_token = env("GRAFANA_TOKEN")

    ics_text = fetch_calendar_ics(nc_url, nc_user, nc_app_password)
    events = parse_events(ics_text)
    posted, skipped = post_annotations(grafana_url, grafana_token, events)
    print(f"garmin-calendar-sync: {posted} posted, {skipped} already present, {len(events)} total in window")


if __name__ == "__main__":
    main()
