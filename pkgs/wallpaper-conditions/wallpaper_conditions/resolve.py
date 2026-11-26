"""Collection matching and ranking inside one theme."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .library import Library
from .model import DIMENSIONS, Collection, Theme


@dataclass(frozen=True)
class Match:
    collection: Collection
    files: tuple[Path, ...]
    rank: int
    specificity: int
    priority: int = 0


@dataclass(frozen=True)
class Resolution:
    phase: str
    weather: str | None
    matches: tuple[Match, ...]
    chosen: Match | None
    fallback_file: Path
    fallback_blurred: Path | None

    @property
    def collection_name(self) -> str | None:
        return self.chosen.collection.name if self.chosen is not None else None

    @property
    def files(self) -> tuple[Path, ...]:
        if self.chosen is not None:
            return self.chosen.files
        return (self.fallback_file,)

    @property
    def blurred(self) -> Path | None:
        if self.chosen is not None:
            return None
        return self.fallback_blurred


def _rank(collection: Collection, order: tuple[str, ...]) -> int:
    ranks = [
        order.index(dimension)
        for dimension in DIMENSIONS
        if getattr(collection, dimension)
    ]
    return min(ranks) if ranks else len(order)


def resolve(
    theme: Theme,
    library: Library,
    *,
    phase: str,
    weather: str | None,
    order: tuple[str, ...],
    fallback_file: Path,
    fallback_blurred: Path | None,
) -> Resolution:
    matches = []
    for collection in theme.collections:
        if not collection.matches(phase=phase, weather=weather):
            continue
        files = library.get(collection.name)
        if not files:
            continue
        matches.append(
            Match(
                collection=collection,
                files=files,
                rank=_rank(collection, order),
                specificity=collection.specificity,
                priority=collection.priority,
            )
        )

    # More predicates beats fewer; an explicit priority breaks ties between
    # equally specific collections; the dimension order then decides which
    # predicate matters (phase before weather by default). The name keeps the
    # sort stable for the remaining ties.
    matches.sort(
        key=lambda match: (
            -match.specificity,
            -match.priority,
            match.rank,
            match.collection.name,
        )
    )
    return Resolution(
        phase=phase,
        weather=weather,
        matches=tuple(matches),
        chosen=matches[0] if matches else None,
        fallback_file=fallback_file,
        fallback_blurred=fallback_blurred,
    )
