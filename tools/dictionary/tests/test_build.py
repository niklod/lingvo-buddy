import io
import sqlite3
import unittest
from contextlib import closing, redirect_stderr

from lingvo_dict import build
from tests.support import BatchFolder, full_batch, lookup_entry, make_word_list, quiz_entry, run_main


class BuildTest(unittest.TestCase):
    def setUp(self):
        self.folder = BatchFolder().__enter__()
        self.addCleanup(self.folder.__exit__)
        self.word_list = make_word_list()
        lines = ["# source: wordfreq 3.1.1 (en)", "# license: wordfreq data by Robyn Speer, CC BY-SA 4.0"]
        lines += [f"{rank}\t{word}" for rank, word in enumerate(self.word_list.headwords, start=1)]
        self.word_list_path = self.folder.path / "wordlist.tsv"
        self.word_list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        self.out = self.folder.path / "out" / "dictionary.sqlite"
        self.exclusions_path = self.folder.write_exclusions()

    def run_build(self, *args):
        return run_main(
            build.main,
            "--word-list", str(self.word_list_path),
            "--batches", str(self.folder.path),
            "--out", str(self.out),
            "--quiz-exclusions", str(self.exclusions_path),
            *args,
        )

    def query(self, sql, *params):
        with closing(sqlite3.connect(self.out)) as connection:
            return connection.execute(sql, params).fetchall()

    def test_builds_entries_translations_and_meta_from_the_batches(self):
        self.folder.write(1, [quiz_entry(self.word_list, 3, translations=["большой", "крупный"], synonym_group="big")])
        self.folder.write(3, [lookup_entry(self.word_list, 1001)])

        code, out, err = self.run_build("--allow-partial")

        self.assertEqual(code, 0, err)
        self.assertIn("2 entries", out)
        self.assertEqual(
            self.query("SELECT id, headword, rank, pos, ipa, example, synonym_group, tier FROM entries ORDER BY rank"),
            [
                (3, "large", 3, "noun", "/haʊs/", "This large is very old.", "big", "quiz"),
                (1001, self.word_list.headword_at(1001), 1001, "noun", "/haʊs/", None, None, "lookup"),
            ],
        )
        self.assertEqual(
            self.query("SELECT entry_id, lang, ord, text FROM translations WHERE entry_id = 3 ORDER BY ord"),
            [(3, "ru", 0, "большой"), (3, "ru", 1, "крупный")],
        )
        self.assertEqual(self.query("PRAGMA journal_mode"), [("delete",)])
        # Same contract as LingvoCore's DictionarySchema (schema version and RU lookup index).
        self.assertEqual(self.query("PRAGMA user_version"), [(2,)])
        self.assertEqual(
            self.query("SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'translations_text'"),
            [("translations_text",)],
        )
        meta = dict(self.query("SELECT key, value FROM meta"))
        self.assertEqual(meta["source"], "wordfreq 3.1.1 (en)")
        self.assertIn("CC BY-SA 4.0", meta["license"])
        self.assertIn("batch-01, batch-03", meta["built_from"])

    def test_quiz_exclusions_of_built_words_go_into_the_dictionary(self):
        self.folder.write(3, [lookup_entry(self.word_list, 1001), lookup_entry(self.word_list, 1002)])
        excluded = self.word_list.headword_at(1002)
        self.folder.write_exclusions(excluded, self.word_list.headword_at(1500))

        code, out, err = self.run_build("--allow-partial")

        self.assertEqual(code, 0, err)
        self.assertIn("2 quiz exclusions", out)
        # Rank 1500 is not in this partial build, so only the built word is written.
        self.assertEqual(self.query("SELECT headword FROM quiz_exclusions"), [(excluded,)])

    def test_invalid_quiz_exclusions_stop_the_build(self):
        self.folder.write(3, [lookup_entry(self.word_list, 1001)])
        self.folder.write_exclusions("nosuchword")

        code, _, err = self.run_build("--allow-partial")

        self.assertEqual(code, 1)
        self.assertIn("'nosuchword': not a headword of the word list", err)
        self.assertFalse(self.out.exists())

    def test_invalid_batches_stop_the_build_and_write_nothing(self):
        self.folder.write(1, [quiz_entry(self.word_list, 4, pos="thing")])

        code, _, err = self.run_build("--allow-partial")

        self.assertEqual(code, 1)
        self.assertIn("pos 'thing'", err)
        self.assertFalse(self.out.exists())

    def test_coverage_flags_apply_to_the_build(self):
        self.folder.write(1, full_batch(self.word_list, 1))

        code, _, err = self.run_build("--through", "1000")

        self.assertEqual(code, 1)
        self.assertIn("coverage: missing ranks 501-1000", err)

    def test_a_build_without_a_coverage_flag_is_refused(self):
        self.folder.write(1, full_batch(self.word_list, 1))

        with self.assertRaises(SystemExit) as raised, redirect_stderr(io.StringIO()) as err:
            build.main(
                ["--word-list", str(self.word_list_path), "--batches", str(self.folder.path), "--out", str(self.out)]
            )

        self.assertEqual(raised.exception.code, 2)
        self.assertIn("pass --full, --through RANK or --allow-partial", err.getvalue())
        self.assertFalse(self.out.exists())

    def test_rebuilding_the_same_batches_gives_the_same_bytes(self):
        self.folder.write(1, full_batch(self.word_list, 1))

        self.run_build("--through", "500")
        first = self.out.read_bytes()
        self.run_build("--through", "500")

        self.assertEqual(self.out.read_bytes(), first)


if __name__ == "__main__":
    unittest.main()
