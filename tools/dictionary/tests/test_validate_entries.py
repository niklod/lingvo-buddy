import unittest

from lingvo_dict.validate import ValidationOptions, validate_batches
from lingvo_dict.wordlist_file import WordList
from tests.support import BatchFolder, lookup_entry, make_word_list, quiz_entry

PARTIAL = ValidationOptions(allow_partial=True)


class EntryRulesTest(unittest.TestCase):
    def setUp(self):
        self.word_list = make_word_list()
        self.folder = BatchFolder().__enter__()
        self.addCleanup(self.folder.__exit__)

    def errors_for(self, number, entries):
        path = self.folder.write(number, entries)
        return validate_batches([path], self.word_list, PARTIAL).errors

    def assert_one_error(self, errors, fragment):
        self.assertEqual(len(errors), 1, errors)
        self.assertIn(fragment, errors[0])

    def test_valid_quiz_and_lookup_entries_pass(self):
        self.assertEqual(self.errors_for(1, [quiz_entry(self.word_list, 4)]), ())
        self.assertEqual(self.errors_for(3, [quiz_entry(self.word_list, 1001)]), ())
        self.assertEqual(self.errors_for(5, [lookup_entry(self.word_list, 2001)]), ())

    def test_headword_must_match_the_word_list_rank(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, headword="home", example="This home is very old.")])

        self.assert_one_error(errors, "word list has 'house' at rank 4")

    def test_rank_must_be_inside_the_batch_range(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 501)])

        self.assert_one_error(errors, "outside batch-01 ranks 1-500")

    def test_missing_and_unknown_fields_are_reported(self):
        entry = quiz_entry(self.word_list, 4, note="extra")
        del entry["ipa"]

        errors = self.errors_for(1, [entry])

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(any("missing field 'ipa'" in e for e in errors))
        self.assertTrue(any("unknown field 'note'" in e for e in errors))

    def test_tier_must_follow_the_rank(self):
        errors = self.errors_for(5, [lookup_entry(self.word_list, 2001, tier="quiz")])

        self.assertTrue(any("tier must be 'lookup'" in e for e in errors), errors)

    def test_pos_must_be_one_of_the_contract_values(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, pos="phrasal verb")])

        self.assert_one_error(errors, "pos 'phrasal verb'")

    def test_translations_must_be_cyrillic(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, translations=["дом", "house"])])

        self.assert_one_error(errors, "translation 'house' must be Cyrillic")

    def test_non_string_translations_are_errors_not_crashes(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, translations=[["дом"], {"a": 1}, 1])])

        self.assertEqual(len(errors), 3, errors)
        self.assertTrue(all("must be Cyrillic" in e for e in errors), errors)

    def test_a_latin_letter_inside_a_cyrillic_word_is_rejected(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, translations=["дoм"])])

        self.assert_one_error(errors, "translation 'дoм' must be Cyrillic")

    def test_translations_must_not_have_extra_spaces(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, translations=["дом ", "в  течение"])])

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(all("must be Cyrillic" in e for e in errors), errors)

    def test_a_translation_has_at_most_forty_characters(self):
        longest = "д" * 40
        entries = [
            quiz_entry(self.word_list, 3, translations=[longest]),
            quiz_entry(self.word_list, 4, translations=[longest + "д"]),
        ]

        errors = self.errors_for(1, entries)

        self.assert_one_error(errors, "is longer than 40 characters")
        self.assertIn("rank 4", errors[0])

    def test_example_has_ten_to_one_hundred_forty_characters(self):
        entries = [
            quiz_entry(self.word_list, 1, example="To be " + "very " * 26 + "fine."),
            quiz_entry(self.word_list, 2, example="Big cats."),
            quiz_entry(self.word_list, 3, example="Big large."),
            quiz_entry(self.word_list, 4, example="This house " + "very " * 25 + "old."),
        ]

        errors = self.errors_for(1, entries)

        self.assertEqual(len(errors), 2, errors)
        self.assertIn("rank 1 'be': example must have 10 to 140 characters, got 141", errors[0])
        self.assertIn("rank 2 'big': example must have 10 to 140 characters, got 9", errors[1])

    def test_translations_allow_spaces_hyphens_and_capitals(self):
        entry = quiz_entry(self.word_list, 5, translations=["что-нибудь", "в течение", "Москва"])

        self.assertEqual(self.errors_for(1, [entry]), ())

    def test_quiz_tier_has_one_to_three_translations(self):
        too_many = quiz_entry(self.word_list, 4, translations=["дом", "здание", "жильё", "кров"])
        empty = quiz_entry(self.word_list, 3, translations=[])

        errors = self.errors_for(1, [empty, too_many])

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(all("1 to 3 translations" in e for e in errors))

    def test_lookup_tier_allows_up_to_five_translations(self):
        entry = lookup_entry(self.word_list, 2001, translations=["а", "б", "в", "г", "д"])

        self.assertEqual(self.errors_for(5, [entry]), ())

    def test_translations_must_be_unique_within_an_entry(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, translations=["дом", "дом"])])

        self.assert_one_error(errors, "duplicate translation 'дом'")

    def test_ipa_must_be_a_slashed_british_transcription(self):
        bad = {
            1: "haʊs",
            2: "/hɚs/",
            3: "/ˈhaʊˈsɪŋ/",
            4: "/ːhaʊs/",
        }
        entries = [quiz_entry(self.word_list, rank, ipa=ipa) for rank, ipa in bad.items()]

        errors = self.errors_for(1, entries)

        self.assertEqual(len(errors), 4, errors)
        self.assertTrue(all("ipa" in e for e in errors))

    def test_valid_ipa_with_stress_and_length_marks_passes(self):
        entry = quiz_entry(self.word_list, 4, ipa="/ˌɪntəˈnæʃənəl/")

        self.assertEqual(self.errors_for(1, [entry]), ())

    def test_quiz_example_must_be_an_english_sentence_with_the_headword(self):
        entries = [
            quiz_entry(self.word_list, 1, example="Это дом."),
            quiz_entry(self.word_list, 2, example="The cat sleeps on the sofa."),
            quiz_entry(self.word_list, 4, example="this house is old"),
        ]

        errors = self.errors_for(1, entries)

        self.assertEqual(len(errors), 3, errors)
        self.assertTrue(any("must contain 'big'" in e for e in errors), errors)

    def test_example_may_use_a_regular_form_of_the_headword(self):
        entry = quiz_entry(self.word_list, 4, example="They are housing the guests tonight.")

        self.assertEqual(self.errors_for(1, [entry]), ())

    def test_example_may_use_tried_for_a_three_letter_y_headword(self):
        self.word_list = WordList(headwords=("be", "try") + self.word_list.headwords[2:])
        entry = quiz_entry(self.word_list, 2, example="I tried it twice today.")

        self.assertEqual(self.errors_for(1, [entry]), ())

    def test_lookup_entry_must_not_carry_quiz_fields(self):
        entry = lookup_entry(self.word_list, 2001, example="Some example here.", synonym_group="be")

        errors = self.errors_for(5, [entry])

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(all("unknown field" in e for e in errors))

    def test_rank_1000_is_quiz_tier_and_needs_a_synonym_group(self):
        entry = quiz_entry(self.word_list, 1000)
        del entry["synonym_group"]

        self.assert_one_error(self.errors_for(2, [entry]), "missing field 'synonym_group'")

    def test_rank_2000_of_the_top_2000_is_quiz_tier_and_needs_an_example(self):
        entry = quiz_entry(self.word_list, 2000)
        del entry["example"]

        self.assert_one_error(self.errors_for(4, [entry]), "missing field 'example'")

    def test_rank_1001_must_not_stay_lookup_tier(self):
        errors = self.errors_for(3, [lookup_entry(self.word_list, 1001)])

        self.assertIn("tier must be 'quiz' for rank 1001, got 'lookup'", " ".join(errors))

    def test_rank_2001_is_lookup_tier_and_takes_no_quiz_fields(self):
        errors = self.errors_for(5, [quiz_entry(self.word_list, 2001)])

        self.assertIn("tier must be 'lookup' for rank 2001, got 'quiz'", " ".join(errors))

    def test_quiz_entry_needs_a_synonym_group(self):
        entry = quiz_entry(self.word_list, 4)
        del entry["synonym_group"]

        self.assert_one_error(self.errors_for(1, [entry]), "missing field 'synonym_group'")


if __name__ == "__main__":
    unittest.main()
