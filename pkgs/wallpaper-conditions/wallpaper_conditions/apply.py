"""Apply a selection through awww and maintain the overview blur cache."""

from __future__ import annotations

import hashlib
import logging
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .resolve import Resolution

LOGGER = logging.getLogger(__name__)

TRANSITION = ("--transition-type", "fade", "--transition-duration", "2")
BLUR_VERSION = "1"
BLUR_FILTERS = (
    "-auto-orient",
    "-resize",
    "25%",
    "-blur",
    "0x6",
    "-resize",
    "400%",
    "-strip",
    "-quality",
    "88",
)
PUBLISH_FILTERS = (
    "-auto-orient",
    "-resize",
    "3840x2160>",
    "-strip",
    "-quality",
    "92",
)


class ApplyError(RuntimeError):
    """The crisp wallpaper could not be applied."""


@dataclass(frozen=True)
class ApplyResult:
    applied: bool
    reason: str


def _run(
    command: list[str],
    timeout: float | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        timeout=timeout,
    )


def backend_ready(namespace: str | None = None) -> bool:
    command = ["awww", "query"]
    if namespace is not None:
        command += ["-n", namespace]
    try:
        return _run(command, timeout=5).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def crisp_command(path: Path) -> list[str]:
    return ["awww", "img", str(path), *TRANSITION]


def backdrop_command(path: Path) -> list[str]:
    return ["awww", "img", "--namespace", "backdrop", str(path), *TRANSITION]


def _render(source: Path, target: Path, filters: tuple[str, ...], stage: str) -> bool:
    """Write ``source`` into ``target`` through ImageMagick, atomically.

    A failed conversion keeps the previous target and drops the temporary file,
    so a consumer never reads a half-written image.
    """

    temporary = target.with_name(f"{target.stem}.tmp.jpg")
    try:
        result = _run(["magick", str(source), *filters, str(temporary)])
    except OSError as exc:
        LOGGER.warning("cannot execute ImageMagick: %s", exc)
        return False
    if result.returncode != 0:
        LOGGER.warning("%s failed for %s: %s", stage, source, result.stderr.strip())
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        return False
    os.replace(temporary, target)
    return True


def _blur_target(source: Path, cache_dir: Path) -> Path | None:
    try:
        stat = source.stat()
    except OSError:
        return None
    key = hashlib.sha256(
        f"{source}:{stat.st_mtime_ns}:{stat.st_size}:{BLUR_VERSION}".encode()
    ).hexdigest()[:32]
    return cache_dir / "blur" / f"{key}.jpg"


def blurred_for(
    resolution: Resolution,
    source: Path,
    cache_dir: Path,
    *,
    generate: bool = True,
) -> Path | None:
    """Return the backdrop for ``source``; generate it into the cache if needed.

    Repository wallpapers keep a hand-made ``_blurred`` sibling (the niri
    overview frame). Library wallpapers have no twin, so the crisp image is
    blurred once and cached by content identity.
    """

    if resolution.chosen is None:
        fallback = resolution.fallback_blurred
        if fallback is not None and fallback.is_file():
            return fallback
        return None

    sibling = source.with_name(f"{source.stem}_blurred{source.suffix}")
    if sibling.is_file():
        return sibling

    target = _blur_target(source, cache_dir)
    if target is None:
        LOGGER.warning("cannot read wallpaper %s", source)
        return None
    if target.is_file() or not generate:
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    if not _render(source, target, BLUR_FILTERS, "blur"):
        return None
    return target


def publish_current(source: Path, target: Path) -> bool:
    """Write a stable JPEG copy for consumers such as the homepage."""

    try:
        source.stat()
    except OSError as exc:
        LOGGER.warning("cannot read wallpaper %s: %s", source, exc)
        return False

    # The pool root is a mountpoint owned by the user; never create it. Doing
    # so while the dataset is unmounted would leave a shadow directory on the
    # root filesystem that hides the published file once the pool mounts.
    if not target.parent.is_dir():
        LOGGER.warning("cannot publish to %s: %s is missing", target, target.parent)
        return False

    return _render(source, target, PUBLISH_FILTERS, "publish")


def apply(
    resolution: Resolution,
    chosen: Path,
    cache_dir: Path,
    *,
    dry_run: bool = False,
) -> ApplyResult:
    crisp = crisp_command(chosen)
    if dry_run:
        blurred = blurred_for(resolution, chosen, cache_dir, generate=False)
        print(" ".join(crisp))
        if blurred is not None:
            print(" ".join(backdrop_command(blurred)))
        return ApplyResult(False, "dry run")

    if not backend_ready():
        return ApplyResult(False, "no awww daemon")

    try:
        result = _run(crisp)
    except OSError as exc:
        raise ApplyError(f"cannot execute awww: {exc}") from exc
    if result.returncode != 0:
        stderr = result.stderr.strip()
        if "none of the requested outputs are valid" in stderr:
            # A session start races the display hotplug: the daemon answers
            # queries before it has an output, and awww rejects the image.
            # The ten-minute timer retries, so a monitor that is not ready
            # must not turn the start unit into a failure.
            return ApplyResult(False, "no output available yet")
        raise ApplyError(f"awww rejected {chosen}: {stderr}")

    # The crisp surface is already visible; the backdrop follows once the blur
    # is ready. A missing backdrop daemon is normal for shells that own the
    # wallpaper themselves, so it is not an error.
    blurred = blurred_for(resolution, chosen, cache_dir)
    if blurred is not None and backend_ready("backdrop"):
        try:
            backdrop_result = _run(backdrop_command(blurred))
        except OSError as exc:
            backdrop_result = None
            LOGGER.warning("cannot execute awww for the backdrop: %s", exc)
        if backdrop_result is not None and backdrop_result.returncode != 0:
            LOGGER.warning("backdrop wallpaper failed: %s", backdrop_result.stderr.strip())

    return ApplyResult(True, f"applied {chosen}")
