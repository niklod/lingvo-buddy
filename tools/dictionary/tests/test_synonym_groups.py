import unittest

from lingvo_dict import validate
from lingvo_dict.validate import ValidationOptions, validate_batches
from tests.support import BatchFolder, full_batch, make_word_list, quiz_entry, run_main

PARTIAL = ValidationOptions(allow_partial=True)


class SynonymGroupRulesTest(unittest.TestCase):
    def setUp(self):
        self.word_list = make_word_list()
        self.folder = BatchFolder().__enter__()
        self.addCleanup(self.folder.__exit__)

    def errors_of(self, *batches, options=PARTIAL):
        paths = [self.folder.write(number, entries) for number, entries in batches]
        return validate_batches(paths, self.word_list, options).errors

    def test_key_must_be_the_headword_of_a_quiz_entry_of_a_complete_loaded_batch(self):
        batch = full_batch(self.word_list, 1)
        renamed = {"headword": "bigger", "example": "This bigger one is old.", "synonym_group": "be"}
        batch[1] = quiz_entry(self.word_list, 2, **renamed)
        batch[2] = quiz_entry(self.word_list, 3, synonym_group="big")

        errors = self.errors_of((1, batch), options=ValidationOptions())

        self.assertEqual(len(errors), 2, errors)
        self.assertIn("rank 2 'bigger': headword 'bigger' does not match", errors[0])
        self.assertIn("rank 3 'large': synonym_group 'big' is not the headword of a quiz entry", errors[1])

    def test_a_chain_names_the_final_key_of_the_group(self):
        entries = [
            quiz_entry(self.word_list, 1),
            quiz_entry(self.word_list, 2, synonym_group="be"),
            quiz_entry(self.word_list, 3, synonym_group="big"),
            quiz_entry(self.word_list, 4, synonym_group="large"),
        ]

        errors = self.errors_of((1, entries))

        self.assertEqual(len(errors), 2, errors)
        self.assertIn("rank 3 'large': synonym_group 'big' belongs to group 'be'; use 'be'", errors[0])
        self.assertIn("rank 4 'house': synonym_group 'large' belongs to group 'be'; use 'be'", errors[1])

    def test_a_loop_of_keys_is_reported_and_does_not_hang(self):
        entries = [
            quiz_entry(self.word_list, 2, synonym_group="large"),
            quiz_entry(self.word_list, 3, synonym_group="big"),
        ]

        errors = self.errors_of((1, entries))

        self.assertTrue(any("'large' has a higher rank" in e for e in errors), errors)
        self.assertTrue(any("rank 3 'large': synonym_group 'big' is in a loop of keys" in e for e in errors), errors)

    def test_key_of_a_batch_in_progress_or_not_loaded_is_checked_against_the_word_list_only(self):
        early_key = self.word_list.headword_at(10)

        errors = self.errors_of(
            (1, [quiz_entry(self.word_list, 3, synonym_group="big")]),
            (2, [quiz_entry(self.word_list, 600, synonym_group=early_key)]),
        )

        self.assertEqual(errors, ())


class SharedTranslationReportTest(unittest.TestCase):
    def setUp(self):
        self.folder = BatchFolder().__enter__()
        self.addCleanup(self.folder.__exit__)
        self.word_list = make_word_list()
        self.word_list_path = self.folder.write_raw(
            "wordlist.tsv", "".join(f"{rank}\t{word}\n" for rank, word in enumerate(self.word_list.headwords, start=1))
        )

    def run_cli(self, *args):
        return run_main(
            validate.main,
            "--word-list", str(self.word_list_path),
            "--quiz-exclusions", str(self.folder.path / "quiz-exclusions.txt"),
            "--allow-partial",
            *args,
        )

    def test_lists_shared_first_translations_across_groups_and_split_ones_inside_a_group_without_failing(self):
        self.folder.write_exclusions()
        path = self.folder.write(1, [
            quiz_entry(self.word_list, 1, translations=["быть"]),
            quiz_entry(self.word_list, 2, translations=["большой", "крупный"]),
            quiz_entry(self.word_list, 3, translations=["большой"]),
            quiz_entry(self.word_list, 4, translations=["дом"], synonym_group="be"),
        ])

        code, out, err = self.run_cli("--report-shared-translations", str(path))

        self.assertEqual(code, 0, err)
        self.assertIn("same first translation, different groups: 1", out)
        self.assertIn("  большой: big(2) -> big; large(3) -> large", out)
        self.assertIn("one group, different first translations: 1", out)
        self.assertIn("  be: be(1) быть; house(4) дом", out)

    def test_leaves_out_quiz_exclusions_and_stays_silent_without_the_option(self):
        excluded = self.word_list.headword_at(1200)
        self.folder.write_exclusions(excluded)
        path = self.folder.write(3, [
            quiz_entry(self.word_list, 1100, translations=["дом"]),
            quiz_entry(self.word_list, 1200, translations=["дом"]),
        ])

        _, report, _ = self.run_cli("--report-shared-translations", str(path))
        _, plain, _ = self.run_cli(str(path))

        self.assertIn("same first translation, different groups: 0", report)
        self.assertNotIn(excluded, report)
        self.assertNotIn("same first translation", plain)


if __name__ == "__main__":
    unittest.main()
