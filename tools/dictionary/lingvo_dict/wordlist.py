"""Turns a word-frequency list into a ranked list of lemmas.

Pure logic only: the frequency source and the lemmatizer are passed in, so the
ranking rules are testable without wordfreq or simplemma installed.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Callable, Optional

WORD_PATTERN = re.compile(r"[a-z]+")

Lemmatize = Callable[[str], Optional[str]]


@dataclass(frozen=True)
class ExportRules:
    exclusions: frozenset  # lowercase lemmas that never enter the list
    keep: frozenset  # cased headwords kept although capitalized or unknown
    lemma_overrides: Mapping[str, str]  # form -> lemma, wins over the lemmatizer


@dataclass(frozen=True)
class RankedWord:
    rank: int
    headword: str


@dataclass(frozen=True)
class Exclusion:
    lemma: str
    reason: str
    frequency: float


@dataclass(frozen=True)
class WordListResult:
    words: tuple[RankedWord, ...]
    excluded: tuple[Exclusion, ...]


@dataclass(frozen=True)
class _Decision:
    key: str
    headword: str
    reason: str | None


def rank_lemmas(
    forms: Iterable[tuple[str, float]],  # most frequent first
    lemmatize: Lemmatize,
    rules: ExportRules,
    limit: int,
) -> WordListResult:
    keep_by_key = {word.lower(): word for word in rules.keep}
    totals: dict[str, float] = {}
    decisions: dict[str, _Decision] = {}

    for form, frequency in forms:
        decision = _decide(form, lemmatize, rules, keep_by_key)
        totals[decision.key] = totals.get(decision.key, 0.0) + frequency
        decisions[decision.key] = _merge(decisions.get(decision.key), decision)

    ordered = sorted(totals, key=lambda key: (-totals[key], key))
    kept = [key for key in ordered if decisions[key].reason is None][:limit]
    threshold = totals[kept[-1]] if len(kept) == limit else 0.0

    words = tuple(
        RankedWord(rank=index + 1, headword=decisions[key].headword)
        for index, key in enumerate(kept)
    )
    excluded = tuple(
        Exclusion(lemma=decisions[key].headword, reason=decisions[key].reason, frequency=totals[key])
        for key in ordered
        if decisions[key].reason is not None and totals[key] >= threshold
    )
    return WordListResult(words=words, excluded=excluded)


def _merge(previous: _Decision | None, current: _Decision) -> _Decision:
    """The most frequent form decides for its lemma; the exclusion list always wins."""
    if previous is None or current.reason == "exclusion-list":
        return current
    return previous


def _decide(
    form: str, lemmatize: Lemmatize, rules: ExportRules, keep_by_key: Mapping[str, str]
) -> _Decision:
    if not WORD_PATTERN.fullmatch(form):
        return _Decision(key=form, headword=form, reason="not-a-word")
    if len(form) == 1:
        return _Decision(key=form, headword=form, reason="single-letter")
    if form in rules.exclusions:
        return _Decision(key=form, headword=form, reason="exclusion-list")

    lemma = rules.lemma_overrides.get(form) or lemmatize(form)
    if lemma is None:
        kept = keep_by_key.get(form)
        if kept is None:
            return _Decision(key=form, headword=form, reason="unknown-word")
        lemma = kept
    lemma = rules.lemma_overrides.get(lemma.lower(), lemma)

    key = lemma.lower()
    if len(key) == 1:
        return _Decision(key=key, headword=key, reason="single-letter")
    if key in rules.exclusions:
        return _Decision(key=key, headword=key, reason="exclusion-list")
    if key in keep_by_key:
        return _Decision(key=key, headword=keep_by_key[key], reason=None)
    if lemma != key:
        return _Decision(key=key, headword=lemma, reason="proper-noun")
    if not WORD_PATTERN.fullmatch(key):
        return _Decision(key=key, headword=key, reason="not-a-word")
    return _Decision(key=key, headword=key, reason=None)


def format_word_list(words: Iterable[RankedWord], header: list[str]) -> str:
    return _format_tsv(header, ((word.rank, word.headword) for word in words))


def format_exclusion_report(excluded: Iterable[Exclusion], header: list[str]) -> str:
    return _format_tsv(header, ((item.lemma, item.reason) for item in excluded))


def _format_tsv(header: Iterable[str], rows: Iterable[tuple[object, ...]]) -> str:
    lines = [f"# {line}" for line in header]
    lines += ["\t".join(str(cell) for cell in row) for row in rows]
    return "\n".join(lines) + "\n"
