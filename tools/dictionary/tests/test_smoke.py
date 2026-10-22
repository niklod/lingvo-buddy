"""End to end on real data: the committed word list, the smoke batch, the build."""

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from lingvo_dict import build, validate
from lingvo_dict.paths import WORDLIST_FILE
from lingvo_dict.wordlist_file import read_word_list
from tests.support import run_main

SMOKE_BATCHES = Path(__file__).resolve().parents[1] / "smoke"


def run(main, *args):
    code, out, err = run_main(main, *args)
    return code, out + err


class SmokeTest(unittest.TestCase):
    def test_smoke_batch_matches_the_committed_word_list(self):
        code, output = run(validate.main, "--batches", str(SMOKE_BATCHES), "--allow-partial", "--through", "20")

        self.assertEqual(code, 0, output)

    def test_smoke_batch_builds_a_dictionary_with_wordfreq_attribution(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "dictionary.sqlite"

            code, output = run(
                build.main, "--batches", str(SMOKE_BATCHES), "--allow-partial", "--through", "20", "--out", str(out)
            )

            self.assertEqual(code, 0, output)
            with closing(sqlite3.connect(out)) as connection:
                first = connection.execute(
                    "SELECT headword, rank, tier, example_ru FROM entries WHERE rank = 1"
                ).fetchone()
                license_text = connection.execute("SELECT value FROM meta WHERE key = 'license'").fetchone()[0]
                source = connection.execute("SELECT value FROM meta WHERE key = 'source'").fetchone()[0]
        self.assertEqual(first, ("be", 1, "quiz", "Я хочу быть врачом."))
        self.assertIn("wordfreq", license_text)
        self.assertIn("CC BY-SA 4.0", license_text)
        self.assertTrue(source.startswith("wordfreq 3.1.1"), source)

    def test_committed_word_list_has_ten_thousand_lemmas(self):
        word_list = read_word_list(WORDLIST_FILE)

        self.assertEqual(word_list.size, 10000)
        self.assertEqual(len(set(word_list.headwords)), 10000)
        for form in ("was", "said", "the", "1"):
            self.assertNotIn(form, word_list.headwords)


if __name__ == "__main__":
    unittest.main()
