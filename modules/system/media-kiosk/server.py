#!/usr/bin/env python3
"""Media kiosk action and preview API.

Serves the kiosk page from the Nix store and exposes the small action surface
the page needs. Everything stays on 127.0.0.1; API keys are read from the
environment file rendered by sops and never reach the browser.

Why this exists: no maintained controller-first launcher covers Jellyfin,
Immich, Cinejoy, Moonlight, desktop wake and audio routing inside one niri
session. This service is the thin backend for the one page that does.

The Jellyfin and Immich preview fetchers are the only outbound HTTP clients.
They talk to loopback services, so proxy environment variables are deliberately
ignored (a desktop proxy would otherwise try to relay 127.0.0.1).
"""

import json
import mimetypes
import os
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CONFIG = {}
WEB_ROOT = Path()
CACHE = Path()

JELLYFIN_BASE = ""
IMMICH_BASE = ""
JELLYFIN_KEY = ""
IMMICH_KEY = ""
IMMICH_EMAIL = ""
IMMICH_PASSWORD = ""

CSP_FRAME_SRC = ""

ACTION = None
ACTION_LOCK = threading.Lock()

KIOSK_WINDOW_TITLE = "Kiosk"
AUDIO_OUTPUTS = {"flip6", "xgo", "xm4", "hdmi"}

# Bounded action log kept for the error dialog. Moonlight logs a few lines on
# a normal start, so twenty lines are enough to show the actual failure.
MAX_ACTION_LINES = 20


def log(message):
    print(f"media-kiosk: {message}", file=sys.stderr, flush=True)


def opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def http_json(url, headers=None, body=None, method=None, timeout=8):
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)

    data = None
    if body is not None:
        data = json.dumps(body).encode()
        request_headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        url,
        data=data,
        headers=request_headers,
        method=method or ("POST" if data is not None else "GET"),
    )
    try:
        with opener().open(request, timeout=timeout) as response:
            payload = response.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:300]
        raise RuntimeError(f"HTTP {error.code} from {url}: {detail}") from error


def http_bytes(url, headers=None, timeout=10):
    request = urllib.request.Request(url, headers=headers or {})
    with opener().open(request, timeout=timeout) as response:
        return response.read()


def write_atomic(path, payload, mode=0o600):
    temporary = path.with_name(path.name + ".tmp")
    with open(temporary, "wb") as handle:
        handle.write(payload)
    os.chmod(temporary, mode)
    os.replace(temporary, path)


def write_json(path, value):
    write_atomic(path, json.dumps(value).encode())


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def jellyfin_headers():
    return {
        "X-Emby-Token": JELLYFIN_KEY,
        "Authorization": f'MediaBrowser Token="{JELLYFIN_KEY}"',
    }


def immich_headers():
    return {"x-api-key": IMMICH_KEY}


def refresh_jellyfin():
    if not JELLYFIN_KEY:
        return

    try:
        users = http_json(f"{JELLYFIN_BASE}/Users", headers=jellyfin_headers())
        # IsHidden only drops a user from the login screen; the API key still
        # acts as that user, so a hidden administrator remains a valid library
        # owner for the preview.
        visible = [
            user
            for user in users
            if not (user.get("Policy") or {}).get("IsDisabled")
        ]
        if not visible:
            raise RuntimeError("Jellyfin has no enabled users")

        # The kiosk is a single-user appliance. Prefer the administrator so a
        # fresh install with a disabled guest still resolves a library owner.
        user = next(
            (u for u in visible if (u.get("Policy") or {}).get("IsAdministrator")),
            visible[0],
        )
        user_id = user["Id"]

        params = urllib.parse.urlencode(
            {
                "userId": user_id,
                "limit": 1,
                "mediaTypes": "Video",
                "fields": "PrimaryImageAspectRatio",
                "imageTypeLimit": 1,
                "enableImageTypes": "Primary",
                "enableTotalRecordCount": "false",
            }
        )
        resume = http_json(
            f"{JELLYFIN_BASE}/UserItems/Resume?{params}",
            headers=jellyfin_headers(),
        )
        items = resume.get("Items") or []
        recently_added = not items

        if not items:
            params = urllib.parse.urlencode(
                {
                    "userId": user_id,
                    "SortBy": "DateCreated",
                    "SortOrder": "Descending",
                    "IncludeItemTypes": "Movie,Series",
                    "Recursive": "true",
                    "Limit": 1,
                    "imageTypeLimit": 1,
                    "enableImageTypes": "Primary",
                    "fields": "PrimaryImageAspectRatio",
                }
            )
            latest = http_json(
                f"{JELLYFIN_BASE}/Items?{params}",
                headers=jellyfin_headers(),
            )
            items = latest.get("Items") or []

        if not items:
            raise RuntimeError("Jellyfin returned no resume or recent item")

        item = items[0]
        title = item.get("SeriesName") or item.get("Name") or "Jellyfin"
        subtitle = "Recently added" if recently_added else "Continue watching"

        if item.get("SeriesName"):
            season = item.get("ParentIndexNumber")
            episode = item.get("IndexNumber")
            if season is not None and episode is not None:
                subtitle = f"S{int(season):02d}E{int(episode):02d}"
                if item.get("Name"):
                    subtitle = f"{subtitle}  ·  {item['Name']}"
            elif item.get("Name"):
                subtitle = item["Name"]
        elif item.get("ProductionYear"):
            subtitle = str(item["ProductionYear"])

        image_id = item.get("Id")
        image_tag = (item.get("ImageTags") or {}).get("Primary")
        if not image_tag and item.get("SeriesId"):
            image_id = item["SeriesId"]
            image_tag = item.get("SeriesPrimaryImageTag")

        if image_id and image_tag:
            image_url = (
                f"{JELLYFIN_BASE}/Items/{image_id}/Images/Primary"
                f"?maxWidth=1280&quality=90&tag={image_tag}"
            )
            write_atomic(CACHE / "jellyfin.jpg", http_bytes(image_url, jellyfin_headers()))

        progress = 0.0
        try:
            progress = float((item.get("UserData") or {}).get("PlayedPercentage") or 0)
        except (TypeError, ValueError):
            progress = 0.0

        write_json(
            CACHE / "jellyfin.json",
            {
                "title": title,
                "subtitle": subtitle,
                "itemId": item.get("Id"),
                "progress": round(progress, 1),
                "online": True,
                "updated": int(time.time()),
            },
        )
    except Exception as error:
        log(f"Jellyfin preview failed: {error}")
        metadata = read_json(CACHE / "jellyfin.json") or {
            "title": "Jellyfin",
            "subtitle": "Movies & shows",
        }
        metadata["online"] = False
        metadata.setdefault("updated", int(time.time()))
        write_json(CACHE / "jellyfin.json", metadata)


def immich_web_login():
    """Return a user session token for the Immich web client.

    Immich authenticates its web UI with host cookies instead of localStorage,
    so the kiosk hands the browser the same cookies a manual login returns.
    Cookies ignore ports, which is how the kiosk origin can set them for the
    Immich origin on 127.0.0.1.
    """
    if not IMMICH_EMAIL or not IMMICH_PASSWORD:
        raise RuntimeError("Immich credentials are not configured")
    response = http_json(
        f"{IMMICH_BASE}/api/auth/login",
        body={"email": IMMICH_EMAIL, "password": IMMICH_PASSWORD},
    )
    token = response.get("accessToken")
    if not token:
        raise RuntimeError("Immich login returned no access token")
    return token


def refresh_immich():
    if not IMMICH_KEY:
        return

    try:
        search = http_json(
            # Immich serves its API under /api: the bare paths answer GET with
            # the web app and POST with an Express 404.
            f"{IMMICH_BASE}/api/search/metadata",
            headers=immich_headers(),
            body={
                "size": 8,
                # Newest first keeps the tile a "recent photo". Immich accepts
                # fileCreatedAt, localDateTime, fileSizeInBytes and rating.
                "orderBy": {"field": "localDateTime", "direction": "desc"},
            },
        )
        items = (search.get("assets") or {}).get("items") or []
        item = next((entry for entry in items if entry.get("type") == "IMAGE"), None)
        if item is None:
            raise RuntimeError("Immich returned no image asset")

        asset_id = item["id"]
        thumbnail = http_bytes(
            f"{IMMICH_BASE}/api/assets/{asset_id}/thumbnail?size=preview",
            immich_headers(),
        )
        write_atomic(CACHE / "immich.jpg", thumbnail)

        taken = item.get("localDateTime") or item.get("fileCreatedAt") or ""
        write_json(
            CACHE / "immich.json",
            {
                "title": item.get("originalFileName") or "Recent photo",
                "subtitle": taken[:10] if taken else "Immich",
                "assetId": asset_id,
                "online": True,
                "updated": int(time.time()),
            },
        )
    except Exception as error:
        log(f"Immich preview failed: {error}")
        metadata = read_json(CACHE / "immich.json") or {
            "title": "Immich",
            "subtitle": "Photo library",
        }
        metadata["online"] = False
        metadata.setdefault("updated", int(time.time()))
        write_json(CACHE / "immich.json", metadata)


def preview_loop():
    while True:
        refresh_jellyfin()
        refresh_immich()
        time.sleep(60)


def highlights():
    return {
        "jellyfin": read_json(CACHE / "jellyfin.json"),
        "immich": read_json(CACHE / "immich.json"),
    }


def public_config():
    return {
        "jellyfin": {"webUrl": f"{JELLYFIN_BASE}/web/"},
        "immich": {"webUrl": f"{IMMICH_BASE}/"},
        "cinejoy": {"url": CONFIG["cinejoy"]["url"]},
        "desktop": {
            "host": CONFIG["desktop"]["host"],
            "app": CONFIG["desktop"]["app"],
        },
    }


def audio_status():
    try:
        return {
            "available": True,
            "status": http_json(
                f"{CONFIG['audio']['url'].rstrip('/')}/status", timeout=3
            ),
        }
    except Exception as error:
        return {"available": False, "error": str(error)}


def audio_set(output):
    if output not in AUDIO_OUTPUTS:
        raise ValueError(f"unknown audio output '{output}'")
    return http_json(
        f"{CONFIG['audio']['url'].rstrip('/')}/output/{output}",
        method="POST",
        timeout=20,
    )


def set_initial_audio():
    # A session starts because the projector was just connected, so HDMI is
    # the correct default. This runs once per session, never on a timer, and
    # only before a cast can exist; it must not steal UxPlay mid-stream.
    url = f"{CONFIG['audio']['url'].rstrip('/')}/output/hdmi"
    for attempt in range(3):
        try:
            http_json(url, method="POST", timeout=10)
            log("initial audio output set to hdmi")
            return
        except Exception as error:
            if attempt == 2:
                log(f"audio hub unavailable at session start: {error}")
            time.sleep(2)


def desktop_status():
    try:
        result = subprocess.run(
            [CONFIG["desktop"]["power"], "status"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return {"up": result.stdout.strip() == "up"}
    except Exception as error:
        return {"up": False, "error": str(error)}


def niri_windows():
    try:
        result = subprocess.run(
            [CONFIG["niri"]["bin"], "msg", "--json", "windows"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            log(f"niri windows failed: {result.stderr.strip()}")
            return []
        return json.loads(result.stdout)
    except Exception as error:
        log(f"niri windows failed: {error}")
        return []


def close_app_windows():
    windows = niri_windows()
    kiosk = next(
        (window for window in windows if window.get("title") == KIOSK_WINDOW_TITLE),
        None,
    )
    if kiosk is None:
        # Never guess: without the kiosk marker, closing every Zen window would
        # close the shell itself.
        log("kiosk window not found; not closing app windows")
        return 0

    closed = 0
    for window in windows:
        if window.get("id") == kiosk.get("id"):
            continue
        if window.get("app_id") in ("zen", "zen-beta"):
            subprocess.run(
                [
                    CONFIG["niri"]["bin"],
                    "msg",
                    "action",
                    "close-window",
                    "--id",
                    str(window["id"]),
                ],
                capture_output=True,
                timeout=5,
            )
            closed += 1
    return closed


def open_target(target):
    urls = {
        "cinejoy": CONFIG["cinejoy"]["url"],
        "jellyfin": f"{JELLYFIN_BASE}/web/",
        "immich": f"{IMMICH_BASE}/",
    }
    url = urls.get(target)
    if url is None:
        raise ValueError(f"unknown target '{target}'")

    close_app_windows()
    subprocess.Popen(
        [CONFIG["open"]["command"], url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    log(f"opened {target} in an app window")


def set_state(action, state=None, message=None):
    with ACTION_LOCK:
        if state is not None:
            action["state"] = state
        if message is not None:
            action["message"] = message


def start_process(command):
    return subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )


def read_lines(action, process):
    for line in process.stdout:
        line = line.strip()
        if not line:
            continue
        with ACTION_LOCK:
            action["lines"] = (action["lines"] + [line])[-MAX_ACTION_LINES:]
        set_state(action, message=line[:160])
        if action.get("cancelled"):
            terminate(process)


def terminate(process):
    try:
        os.killpg(os.getpgid(process.pid), signal.SIGTERM)
    except ProcessLookupError:
        return
    except Exception:
        pass
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except Exception:
            pass


def wait_for_port(action):
    host = CONFIG["desktop"]["host"]
    port = CONFIG["desktop"]["port"]
    deadline = time.time() + 90
    while time.time() < deadline:
        if action.get("cancelled"):
            return False
        try:
            with socket.create_connection((host, port), timeout=2):
                return True
        except OSError:
            pass
        set_state(
            action,
            message=f"Waiting for Moonlight… {int(deadline - time.time())}s",
        )
        time.sleep(2)
    return False


def run_action(action):
    try:
        set_state(action, "waking", "Waking the desktop…")
        process = start_process([CONFIG["desktop"]["power"], "on"])
        action["process"] = process
        read_lines(action, process)
        status = process.wait()

        if action.get("cancelled"):
            set_state(action, "cancelled", "Cancelled")
            return
        if status != 0:
            set_state(action, "error", f"desktop-power failed (status {status})")
            return

        set_state(action, "waiting", "Waiting for Moonlight…")
        if not wait_for_port(action):
            if action.get("cancelled"):
                set_state(action, "cancelled", "Cancelled")
            else:
                set_state(action, "error", "Moonlight did not open port 47989")
            return

        set_state(action, "launching", "Starting Moonlight…")
        command = [CONFIG["desktop"]["moonlight"]]
        if action["kind"] == "steam":
            command += [
                "stream",
                CONFIG["desktop"]["host"],
                CONFIG["desktop"]["app"],
            ]

        process = start_process(command)
        action["process"] = process
        time.sleep(1.5)
        if process.poll() is None:
            set_state(action, "streaming", "Streaming")
        read_lines(action, process)
        status = process.wait()

        if action.get("cancelled"):
            set_state(action, "cancelled", "Cancelled")
        elif status != 0:
            set_state(action, "error", f"Moonlight exited with status {status}")
        else:
            set_state(action, "done", "Stream ended")
    except Exception as error:
        log(f"action failed: {error}")
        set_state(action, "error", str(error))
    finally:
        action["process"] = None


def new_action(kind):
    global ACTION
    with ACTION_LOCK:
        if ACTION and ACTION["state"] not in ("done", "error", "cancelled"):
            return None
        ACTION = {
            "id": uuid.uuid4().hex,
            "kind": kind,
            "state": "starting",
            "message": "Starting…",
            "started": time.time(),
            "process": None,
            "cancelled": False,
            "lines": [],
        }
        action = ACTION
    threading.Thread(target=run_action, args=(action,), daemon=True).start()
    return action


def action_status(action):
    with ACTION_LOCK:
        return {
            "id": action["id"],
            "state": action["state"],
            "message": action["message"],
            "elapsed": int(time.time() - action["started"]),
            "error": "\n".join(action["lines"][-6:])
            if action["state"] == "error"
            else None,
        }


def cancel_action(action_id):
    with ACTION_LOCK:
        if not ACTION or ACTION["id"] != action_id:
            return False
        if ACTION["state"] in ("done", "error", "cancelled"):
            return True
        ACTION["cancelled"] = True
        ACTION["state"] = "cancelling"
        ACTION["message"] = "Cancelling…"
        process = ACTION["process"]

    if process is not None:
        terminate(process)
    return True


def exit_kiosk():
    result = subprocess.run(
        [
            CONFIG["systemd"]["systemctl"],
            "--user",
            "stop",
            CONFIG["systemd"]["browserUnit"],
        ],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "systemctl stop failed")


def security_headers(handler):
    handler.send_header("X-Content-Type-Options", "nosniff")
    handler.send_header("Referrer-Policy", "no-referrer")
    handler.send_header("X-Frame-Options", "DENY")
    handler.send_header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
    handler.send_header(
        "Content-Security-Policy",
        "default-src 'self'; "
        "img-src 'self' data:; "
        "font-src 'self'; "
        "style-src 'self' 'unsafe-inline'; "
        "script-src 'self'; "
        "connect-src 'self'; "
        f"frame-src {CSP_FRAME_SRC}; "
        "base-uri 'none'; "
        "form-action 'none'; "
        "frame-ancestors 'none'",
    )


class KioskHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "media-kiosk/1.0"

    def log_message(self, fmt, *args):
        # Keep the journal readable: action and preview failures log
        # explicitly; per-request access logs are noise on a single page.
        return

    def send_json(self, status, value):
        payload = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(payload)))
        security_headers(self)
        self.end_headers()
        self.wfile.write(payload)

    def send_cookies(self, status, cookies):
        self.send_response(status)
        for name, value, http_only in cookies:
            # Immich's own login persists the session for 400 days; a session
            # cookie would log the panel out on every browser restart.
            header = f"{name}={value}; Path=/; SameSite=Lax; Max-Age=34560000"
            if http_only:
                header += "; HttpOnly"
            self.send_header("Set-Cookie", header)
        self.send_header("Cache-Control", "no-store")
        security_headers(self)
        self.end_headers()

    def send_bytes(self, status, payload, content_type, cache):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", cache)
        self.send_header("Content-Length", str(len(payload)))
        security_headers(self)
        self.end_headers()
        self.wfile.write(payload)

    def send_static(self, relative):
        path = (WEB_ROOT / relative.lstrip("/")).resolve()
        if path != WEB_ROOT and WEB_ROOT not in path.parents:
            return self.send_json(404, {"error": "not found"})
        if not path.is_file():
            return self.send_json(404, {"error": "not found"})

        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        if path.name in ("InterVariable.ttf", "wallpaper.jpg", "favicon.svg"):
            # Immutable store assets: safe to cache across kiosk restarts.
            cache = "public, max-age=86400"
        else:
            # app.js and style.css must follow a deploy; the kiosk profile's
            # cache would otherwise serve stale code against a new API.
            cache = "no-store"
        self.send_bytes(200, path.read_bytes(), content_type, cache)

    def send_preview(self, name):
        path = CACHE / f"{name}.jpg"
        if not path.is_file():
            return self.send_json(404, {"error": "preview unavailable"})
        self.send_bytes(200, path.read_bytes(), "image/jpeg", "no-store")

    def do_GET(self):
        try:
            path = urllib.parse.urlparse(self.path).path

            if path in ("/", "/index.html"):
                return self.send_static("index.html")
            if path in ("/app.js", "/style.css") or path.startswith("/static/"):
                return self.send_static(path)
            if path == "/api/health":
                return self.send_json(200, {"ok": True})
            if path == "/api/config":
                return self.send_json(200, public_config())
            if path == "/api/highlights":
                return self.send_json(200, highlights())
            if path == "/api/audio":
                return self.send_json(200, audio_status())
            if path == "/api/desktop":
                return self.send_json(200, desktop_status())
            if path == "/api/preview/jellyfin":
                return self.send_preview("jellyfin")
            if path == "/api/preview/immich":
                return self.send_preview("immich")
            if path.startswith("/api/action/"):
                action_id = path.removeprefix("/api/action/")
                with ACTION_LOCK:
                    action = ACTION
                if not action or action["id"] != action_id:
                    return self.send_json(404, {"error": "unknown action"})
                return self.send_json(200, action_status(action))

            return self.send_json(404, {"error": "not found"})
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as error:
            log(f"GET {self.path} failed: {error}")
            try:
                self.send_json(500, {"error": "internal error"})
            except Exception:
                pass

    def do_POST(self):
        try:
            if self.headers.get("X-Kiosk-Request") != "1":
                return self.send_json(403, {"error": "missing kiosk request header"})

            length = int(self.headers.get("Content-Length") or 0)
            if length > 4096:
                return self.send_json(413, {"error": "request body too large"})
            raw = self.rfile.read(length) if length else b""
            body = json.loads(raw) if raw else {}
            path = urllib.parse.urlparse(self.path).path

            if path == "/api/session/immich":
                # POST-only and behind the kiosk request header, so a page on
                # another origin cannot mint a session with a plain GET. Local
                # processes share the kiosk user's trust boundary anyway.
                try:
                    token = immich_web_login()
                except Exception as error:
                    log(f"Immich web login failed: {error}")
                    return self.send_json(502, {"error": "Immich login failed"})
                return self.send_cookies(
                    204,
                    [
                        ("immich_access_token", token, True),
                        ("immich_auth_type", "password", False),
                        ("immich_is_authenticated", "true", False),
                    ],
                )
            if path == "/api/open":
                open_target(body.get("target"))
                return self.send_json(200, {"ok": True})
            if path == "/api/close-apps":
                return self.send_json(200, {"closed": close_app_windows()})
            if path in ("/api/moonlight/steam", "/api/moonlight/ui"):
                kind = "steam" if path.endswith("steam") else "ui"
                action = new_action(kind)
                if action is None:
                    return self.send_json(
                        409, {"error": "another action is already running"}
                    )
                return self.send_json(202, {"id": action["id"]})
            if path.startswith("/api/action/") and path.endswith("/cancel"):
                action_id = path.removeprefix("/api/action/").removesuffix("/cancel")
                if not cancel_action(action_id):
                    return self.send_json(404, {"error": "unknown action"})
                return self.send_json(200, {"ok": True})
            if path.startswith("/api/audio/output/"):
                output = path.removeprefix("/api/audio/output/")
                audio_set(output)
                return self.send_json(200, {"ok": True})
            if path == "/api/exit":
                exit_kiosk()
                return self.send_json(202, {"ok": True})

            return self.send_json(404, {"error": "not found"})
        except (BrokenPipeError, ConnectionResetError):
            pass
        except ValueError as error:
            self.send_json(400, {"error": str(error)})
        except Exception as error:
            log(f"POST {self.path} failed: {error}")
            try:
                self.send_json(502, {"error": str(error)[:300]})
            except Exception:
                pass


def load_config():
    global CONFIG, WEB_ROOT, CACHE
    global JELLYFIN_BASE, IMMICH_BASE, JELLYFIN_KEY, IMMICH_KEY, CSP_FRAME_SRC
    global IMMICH_EMAIL, IMMICH_PASSWORD

    config_path = os.environ.get("KIOSK_CONFIG")
    web_root = os.environ.get("KIOSK_WEB_ROOT")
    if not config_path or not web_root:
        log("KIOSK_CONFIG and KIOSK_WEB_ROOT must be set")
        return False

    CONFIG = json.loads(Path(config_path).read_text())
    WEB_ROOT = Path(web_root).resolve()
    CACHE = Path(CONFIG["cacheDir"])
    CACHE.mkdir(parents=True, exist_ok=True)
    os.chmod(CACHE, 0o700)

    JELLYFIN_BASE = CONFIG["jellyfin"]["url"].rstrip("/")
    IMMICH_BASE = CONFIG["immich"]["url"].rstrip("/")
    JELLYFIN_KEY = os.environ.get("JELLYFIN_API_KEY", "").strip()
    IMMICH_KEY = os.environ.get("IMMICH_API_KEY", "").strip()
    IMMICH_EMAIL = os.environ.get("IMMICH_EMAIL", "").strip()
    IMMICH_PASSWORD = os.environ.get("IMMICH_PASSWORD", "")
    CSP_FRAME_SRC = f"{JELLYFIN_BASE} {IMMICH_BASE}"

    if not JELLYFIN_KEY:
        log("JELLYFIN_API_KEY missing; Jellyfin preview disabled")
    if not IMMICH_KEY:
        log("IMMICH_API_KEY missing; Immich preview disabled")
    if not IMMICH_EMAIL or not IMMICH_PASSWORD:
        log("IMMICH_EMAIL/IMMICH_PASSWORD missing; Immich web session disabled")
    return True


def main():
    if not load_config():
        return 1

    server = ThreadingHTTPServer((CONFIG["bind"], CONFIG["port"]), KioskHandler)
    server.daemon_threads = True
    log(f"listening on http://{CONFIG['bind']}:{CONFIG['port']}")

    threading.Thread(target=preview_loop, daemon=True).start()
    threading.Thread(target=set_initial_audio, daemon=True).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
