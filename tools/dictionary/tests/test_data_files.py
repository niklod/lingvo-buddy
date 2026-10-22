"""Readers of the hand-edited and generated data files: bad input is an error, not a traceback."""

import tempfile
import unittest
from pathlib import Path

from lingvo_dict import export
from lingvo_dict.wordlist_file import WordListError, parse_word_list, read_word_list
from tests.support import run_main


class WordListFileTest(unittest.TestCase):
    def test_ranks_must_be_ascii_digits(self):
        with self.assertRaisesRegex(WordListError, "line 1: expected 'rank<TAB>headword'"):
            parse_word_list("²\tbar\n")

    def test_ranks_must_follow_each_other(self):
        with self.assertRaisesRegex(WordListError, "line 2: rank 3 out of order, expected 2"):
            parse_word_list("1\tbe\n3\tbig\n")

    def test_a_file_that_is_not_utf8_is_a_word_list_error(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "wordlist.tsv"
            path.write_bytes(b"1\t\xff\n")

            with self.assertRaisesRegex(WordListError, "cannot read word list"):
                read_word_list(path)


class ExportRuleFilesTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.folder = Path(tmp.name)

    def write(self, name, text):
        path = self.folder / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_comments_and_blank_lines_are_skipped(self):
        path = self.write("keep.txt", "x  # c\n\n#only\nNASA\n")

        self.assertEqual(export.read_lines(path), ["x", "NASA"])

    def test_overrides_need_exactly_two_columns(self):
        path = self.write("lemma-overrides.tsv", "gone\tgo\tverb\n")

        with self.assertRaisesRegex(ValueError, "expected 'form<TAB>lemma'"):
            export.read_overrides(path)

    def test_an_override_form_must_not_be_listed_twice(self):
        path = self.write("lemma-overrides.tsv", "gone\tgo\ngone\tgoner\n")

        with self.assertRaisesRegex(ValueError, "'gone' is listed twice"):
            export.read_overrides(path)

    def test_missing_rule_files_exit_two_with_a_message(self):
        code, _, err = run_main(export.main, "--data", str(self.folder))

        self.assertEqual(code, 2)
        self.assertIn("exclusions.txt", err)

    def test_broken_rule_files_exit_two_with_a_message(self):
        self.write("exclusions.txt", "fuck\n")
        self.write("keep.txt", "NASA\n")
        (self.folder / "lemma-overrides.tsv").write_bytes(b"gone\t\xff\n")

        code, _, err = run_main(export.main, "--data", str(self.folder))

        self.assertEqual(code, 2)
        self.assertIn("lemma-overrides.tsv", err)


if __name__ == "__main__":
    unittest.main()
