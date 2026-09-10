#!/usr/bin/env python3
"""Create a detached Zellij session with a real (PTY) client attached.

`zellij attach --create-background` starts the server with no client. The first
tab's status-bar plugin (zjstatus) initialises in that client-less window, gets
empty host-query replies, and is then left rendering an empty bar forever.
Creating the session with a client attached and detaching afterwards avoids it.

Usage: zellij-new [--force] <session-name>
"""
import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time


def fail(msg: str, code: int = 1) -> None:
    print(f"zellij-new: {msg}", file=sys.stderr)
    sys.exit(code)


def session_names() -> list[str]:
    try:
        out = subprocess.run(
            ["zellij", "list-sessions", "--no-formatting"],
            capture_output=True,
            text=True,
            timeout=10,
        ).stdout
    except Exception:
        return []
    names = []
    for line in out.splitlines():
        line = line.strip()
        if line and "EXITED" not in line:
            names.append(line.split()[0])
    return names


def main() -> int:
    force = "--force" in sys.argv[1:]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        fail("usage: zellij-new [--force] <session-name>", 2)
    name = args[0]

    if name in session_names():
        if not force:
            fail(f"session '{name}' already exists (use --force to recreate)", 0)
        subprocess.run(["zellij", "delete-session", "--force", name], timeout=15)

    pid, fd = pty.fork()
    if pid == 0:
        for key in ("ZELLIJ", "ZELLIJ_SESSION_NAME", "ZELLIJ_PANE_ID"):
            os.environ.pop(key, None)
        os.environ["TERM"] = "xterm-256color"
        os.execvp("zellij", ["zellij", "-s", name])

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 45, 180, 0, 0))

    def drain() -> None:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                os.read(fd, 65536)
            except OSError:
                pass

    # Wait for the session to exist, then let its first tab render before we
    # detach (kill the client). The server persists.
    deadline = time.time() + 10
    while time.time() < deadline:
        drain()
        if name in session_names():
            break
        time.sleep(0.25)

    end = time.time() + 3
    while time.time() < end:
        drain()
        time.sleep(0.1)

    try:
        os.kill(pid, 9)
    except ProcessLookupError:
        pass

    if name not in session_names():
        fail(f"session '{name}' did not start")
    print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
