import io
import unittest
from contextlib import redirect_stderr, redirect_stdout

from lingvo_dict import validate
from lingvo_dict.validate import ValidationOptions, validate_batches
from tests.support import BatchFolder, full_batch, make_word_list, quiz_entry

PARTIAL = ValidationOptions(allow_partial=True)


class BatchRulesTest(unittest.TestCase):
    def setUp(self):
        self.word_list = make_word_list()
        self.folder = BatchFolder().__enter__()
        self.addCleanup(self.folder.__exit__)

    def test_a_complete_batch_passes_and_counts_its_entries(self):
        path = self.folder.write(1, full_batch(self.word_list, 1))

        report = validate_batches([path], self.word_list, ValidationOptions())

        self.assertEqual(report.errors, ())
        self.assertEqual(report.entry_count, 500)

    def test_an_incomplete_batch_fails_unless_partial_batches_are_allowed(self):
        entries = full_batch(self.word_list, 1)[:-2]
        path = self.folder.write(1, entries)

        strict = validate_batches([path], self.word_list, ValidationOptions())
        partial = validate_batches([path], self.word_list, PARTIAL)

        self.assertEqual(len(strict.errors), 1, strict.errors)
        self.assertIn("missing ranks 499-500", strict.errors[0])
        self.assertEqual(partial.errors, ())

    def test_a_boolean_rank_does_not_count_as_rank_one(self):
        entries = [{**quiz_entry(self.word_list, 1), "rank": True}] + full_batch(self.word_list, 1)[1:]
        path = self.folder.write(1, entries)

        errors = validate_batches([path], self.word_list, ValidationOptions()).errors

        self.assertEqual(len(errors), 2, errors)
        self.assertIn("rank must be a positive integer, got True", errors[0])
        self.assertIn("missing ranks 1 ", errors[1])

    def test_entries_must_be_sorted_by_rank(self):
        path = self.folder.write(1, [quiz_entry(self.word_list, 4), quiz_entry(self.word_list, 3)])

        errors = validate_batches([path], self.word_list, PARTIAL).errors

        self.assertEqual(len(errors), 1, errors)
        self.assertIn("sorted by rank", errors[0])

    def test_duplicate_ranks_and_headwords_are_reported(self):
        first = self.folder.write(1, [quiz_entry(self.word_list, 4)])
        second = self.folder.write(1, [quiz_entry(self.word_list, 4)], name="batch-01-copy.json", batch="batch-01")

        errors = validate_batches([first, second], self.word_list, PARTIAL).errors

        self.assertTrue(any("duplicate rank 4" in e for e in errors), errors)
        self.assertTrue(any("duplicate headword 'house'" in e for e in errors), errors)

    def test_file_name_must_match_the_batch_id(self):
        path = self.folder.write(1, [quiz_entry(self.word_list, 4)], name="batch-02.json")

        errors = validate_batches([path], self.word_list, PARTIAL).errors

        self.assertEqual(len(errors), 1, errors)
        self.assertIn("file name must be batch-01.json", errors[0])

    def test_broken_json_is_an_error_not_a_crash(self):
        path = self.folder.write_raw("batch-01.json", '{"batch": "batch-01", "entries": [')

        errors = validate_batches([path], self.word_list, PARTIAL).errors

        self.assertEqual(len(errors), 1, errors)
        self.assertIn("invalid JSON", errors[0])

    def test_synonym_group_points_at_a_lower_ranked_quiz_headword(self):
        entries = [
            quiz_entry(self.word_list, 2),
            quiz_entry(self.word_list, 3, synonym_group="big"),
        ]
        path = self.folder.write(1, entries)

        self.assertEqual(validate_batches([path], self.word_list, PARTIAL).errors, ())

    def test_synonym_group_must_not_be_unknown_or_higher_ranked(self):
        entries = [
            quiz_entry(self.word_list, 2, synonym_group="large"),
            quiz_entry(self.word_list, 4, synonym_group="home"),
        ]
        path = self.folder.write(1, entries)

        errors = validate_batches([path], self.word_list, PARTIAL).errors

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(any("'large' has a higher rank" in e for e in errors), errors)
        self.assertTrue(any("'home' is not a quiz-tier headword" in e for e in errors), errors)

    def test_synonym_group_root_must_be_its_own_group(self):
        entries = [
            quiz_entry(self.word_list, 2, synonym_group="be"),
            quiz_entry(self.word_list, 3, synonym_group="big"),
        ]
        path = self.folder.write(1, entries)

        errors = validate_batches([path], self.word_list, PARTIAL).errors

        self.assertEqual(len(errors), 1, errors)
        self.assertIn("'big' belongs to group 'be'", errors[0])

    def test_coverage_through_a_rank_needs_every_rank_up_to_it(self):
        path = self.folder.write(1, full_batch(self.word_list, 1))

        errors = validate_batches([path], self.word_list, ValidationOptions(through_rank=1000)).errors

        self.assertEqual(len(errors), 1, errors)
        self.assertIn("coverage: missing ranks 501-1000", errors[0])

    def test_full_coverage_needs_the_whole_word_list(self):
        paths = [self.folder.write(n, full_batch(self.word_list, n)) for n in (1, 2, 3)]

        errors = validate_batches(paths, self.word_list, ValidationOptions(full=True)).errors

        self.assertEqual(len(errors), 1, errors)
        self.assertIn("coverage: missing ranks 1501-1600", errors[0])


class CommandLineTest(unittest.TestCase):
    def setUp(self):
        self.folder = BatchFolder().__enter__()
        self.addCleanup(self.folder.__exit__)
        self.word_list_path = self.folder.path / "wordlist.tsv"
        word_list = make_word_list()
        lines = [f"{rank}\t{word}" for rank, word in enumerate(word_list.headwords, start=1)]
        self.word_list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        self.word_list = word_list
        self.exclusions_path = self.folder.write_exclusions()

    def run_cli(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = validate.main(
                ["--word-list", str(self.word_list_path), "--quiz-exclusions", str(self.exclusions_path), *args]
            )
        return code, out.getvalue(), err.getvalue()

    def test_exit_code_is_zero_for_valid_batches(self):
        path = self.folder.write(1, full_batch(self.word_list, 1))

        code, out, _ = self.run_cli(str(path))

        self.assertEqual(code, 0)
        self.assertIn("OK: 500 entries in 1 batch", out)

    def test_exit_code_is_one_and_errors_are_printed_for_invalid_batches(self):
        path = self.folder.write(1, [quiz_entry(self.word_list, 4, pos="thing")])

        code, _, err = self.run_cli("--allow-partial", str(path))

        self.assertEqual(code, 1)
        self.assertIn("pos 'thing'", err)

    def test_without_files_it_validates_every_batch_in_the_folder(self):
        self.folder.write(1, full_batch(self.word_list, 1))
        self.folder.write(2, full_batch(self.word_list, 2))

        code, out, _ = self.run_cli("--batches", str(self.folder.path), "--through", "1000")

        self.assertEqual(code, 0)
        self.assertIn("OK: 1000 entries in 2 batches", out)

    def test_quiz_exclusions_must_be_known_lookup_tier_headwords_listed_once(self):
        path = self.folder.write(1, full_batch(self.word_list, 1))
        lookup_word = self.word_list.headword_at(1200)
        self.folder.write_exclusions(
            "# names and fragments",
            f"{lookup_word}  # a fragment",
            f"{lookup_word}",
            "nosuchword",
            self.word_list.headword_at(3),
        )

        code, _, err = self.run_cli(str(path))

        self.assertEqual(code, 1)
        self.assertIn(f"quiz-exclusions.txt:3 '{lookup_word}': listed twice", err)
        self.assertIn("quiz-exclusions.txt:4 'nosuchword': not a headword of the word list", err)
        self.assertIn("quiz-exclusions.txt:5 'large': rank 3 is quiz tier", err)

    def test_valid_quiz_exclusions_are_counted(self):
        path = self.folder.write(1, full_batch(self.word_list, 1))
        self.folder.write_exclusions(self.word_list.headword_at(1200), "", self.word_list.headword_at(1300))

        code, out, err = self.run_cli(str(path))

        self.assertEqual(code, 0, err)
        self.assertIn("2 quiz exclusions", out)


if __name__ == "__main__":
    unittest.main()
