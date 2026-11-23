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


class ApplyError(RuntimeError):
    """The crisp wallpaper could not be applied."""


@dataclass(frozen=True)
class ApplyResult:
    applied: bool
    reason: str


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, check=False)


def backend_ready(namespace: str | None = None) -> bool:
    command = ["awww", "query"]
    if namespace is not None:
        command += ["-n", namespace]
    try:
        return _run(command).returncode == 0
    except OSError:
        return False


def crisp_command(path: Path) -> list[str]:
    return ["awww", "img", str(path), *TRANSITION]


def backdrop_command(path: Path) -> list[str]:
    return ["awww", "img", "--namespace", "backdrop", str(path), *TRANSITION]


def _blur_command(source: Path, target: Path) -> list[str]:
    return [
        "magick",
        str(source),
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
        str(target),
    ]


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

    if resolution.chosen is None and resolution.fallback_blurred is not None:
        return resolution.fallback_blurred if resolution.fallback_blurred.is_file() else None

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
    temporary = target.with_name(f"{target.stem}.tmp.jpg")
    try:
        result = _run(_blur_command(source, temporary))
    except OSError as exc:
        LOGGER.warning("cannot execute ImageMagick: %s", exc)
        return None
    if result.returncode != 0:
        LOGGER.warning("blur failed for %s: %s", source, result.stderr.strip())
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        return None
    os.replace(temporary, target)
    return target


def publish_current(source: Path, target: Path) -> bool:
    """Write a stable JPEG copy for consumers such as the homepage."""

    try:
        source.stat()
    except OSError as exc:
        LOGGER.warning("cannot read wallpaper %s: %s", source, exc)
        return False

    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f"{target.stem}.tmp.jpg")
    command = [
        "magick",
        str(source),
        "-auto-orient",
        "-resize",
        "3840x2160>",
        "-strip",
        "-quality",
        "92",
        str(temporary),
    ]
    try:
        result = _run(command)
    except OSError as exc:
        LOGGER.warning("cannot execute ImageMagick: %s", exc)
        return False
    if result.returncode != 0:
        LOGGER.warning("publish failed for %s: %s", source, result.stderr.strip())
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        return False
    os.replace(temporary, target)
    return True


def apply(
    resolution: Resolution,
    chosen: Path,
    cache_dir: Path,
    *,
    dry_run: bool = False,
) -> ApplyResult:
    crisp = crisp_command(chosen)
    backdrop = None
    if dry_run:
        blurred = blurred_for(resolution, chosen, cache_dir, generate=False)
        backdrop = backdrop_command(blurred) if blurred is not None else None
        print(" ".join(crisp))
        if backdrop is not None:
            print(" ".join(backdrop))
        return ApplyResult(False, "dry run")

    if not backend_ready():
        return ApplyResult(False, "no awww daemon")

    try:
        result = _run(crisp)
    except OSError as exc:
        raise ApplyError(f"cannot execute awww: {exc}") from exc
    if result.returncode != 0:
        raise ApplyError(f"awww rejected {chosen}: {result.stderr.strip()}")

    # The crisp surface is already visible; the backdrop follows once the blur
    # is ready. A missing backdrop daemon is normal for shells that own the
    # wallpaper themselves, so it is not an error.
    blurred = blurred_for(resolution, chosen, cache_dir)
    if blurred is not None and backend_ready("backdrop"):
        try:
            backdrop_result = _run(backdrop_command(blurred))
        except OSError as exc:
            LOGGER.warning("cannot execute awww for the backdrop: %s", exc)
        else:
            if backdrop_result.returncode != 0:
                LOGGER.warning("backdrop wallpaper failed: %s", backdrop_result.stderr.strip())

    return ApplyResult(True, f"applied {chosen}")
