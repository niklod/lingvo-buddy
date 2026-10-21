"""Prints the ranks, headwords and tiers a batch must cover. Usage: python3 tools/dictionary/batch_words.py batch-03."""

import sys

from lingvo_dict.contract import BATCH_COUNT, BATCH_ID_PATTERN, batch_ranks, tier_for_rank
from lingvo_dict.paths import WORDLIST_FILE
from lingvo_dict.wordlist_file import WordListError, read_word_list


def main(argv):
    match = BATCH_ID_PATTERN.fullmatch(argv[0]) if len(argv) == 1 else None
    if match is None or not 1 <= int(match.group(1)) <= BATCH_COUNT:
        print(f"usage: batch_words.py batch-NN (01 to {BATCH_COUNT:02d})", file=sys.stderr)
        return 2
    try:
        word_list = read_word_list(WORDLIST_FILE)
    except WordListError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    first, last = batch_ranks(int(match.group(1)))
    for rank in range(first, min(last, word_list.size) + 1):
        print(f"{rank}\t{word_list.headword_at(rank)}\t{tier_for_rank(rank)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
