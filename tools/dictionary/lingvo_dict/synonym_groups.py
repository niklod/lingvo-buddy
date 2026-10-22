"""Cross-entry rules for synonym_group keys of quiz-tier entries."""

from __future__ import annotations

from typing import Dict, List, Optional, Sequence, Set

from lingvo_dict.contract import BATCH_SIZE, batch_id, is_quiz_rank
from lingvo_dict.loaded_entry import LoadedEntry
from lingvo_dict.wordlist_file import WordList


def check_synonym_groups(entries: Sequence[LoadedEntry], word_list: WordList, allow_partial: bool) -> List[str]:
    ranks = word_list.ranks()
    group_of = {item.headword: item.synonym_group for item in entries if item.synonym_group is not None}
    # A batch in progress may not have the key's entry yet; a complete batch must.
    complete_files = set() if allow_partial else {item.file for item in entries}
    errors = []
    for item in entries:
        group = item.synonym_group
        if not isinstance(group, str) or not group:
            continue
        label = f"{item.file}: rank {item.rank} '{item.headword}'"
        root_rank = ranks.get(group)
        if root_rank is None or not is_quiz_rank(root_rank):
            errors.append(f"{label}: synonym_group '{group}' is not a quiz-tier headword")
        elif root_rank > item.rank:
            errors.append(
                f"{label}: synonym_group '{group}' has a higher rank ({root_rank}) than the entry;"
                " use the lowest-ranked word of the group"
            )
        elif group not in group_of:
            # When one file is validated alone, the key's batch is absent and the word list check is all we have.
            if _batch_file(root_rank) in complete_files:
                errors.append(f"{label}: synonym_group '{group}' is not the headword of a quiz entry")
        elif group_of[group] != group:
            errors.append(f"{label}: synonym_group '{group}' {_chain_advice(group, group_of)}")
    return errors


def _chain_advice(group: str, group_of: Dict[str, Optional[str]]) -> str:
    # Naming the final key, not the next link, makes one fix pass enough for every member of the group.
    final = _final_key(group, group_of)
    if final is None:
        return "is in a loop of keys; point every word of the group at its lowest-ranked word"
    return f"belongs to group '{final}'; use '{final}'"


def _final_key(group: str, group_of: Dict[str, Optional[str]]) -> Optional[str]:
    """Follows keys until a word that is its own key; None when the keys loop."""
    seen: Set[str] = set()
    current = group
    while current in group_of and group_of[current] != current:
        if current in seen:
            return None
        seen.add(current)
        current = group_of[current]
    return current


def _batch_file(rank: int) -> str:
    return f"{batch_id((rank - 1) // BATCH_SIZE + 1)}.json"
