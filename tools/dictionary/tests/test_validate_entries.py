import unittest

from lingvo_dict.validate import ValidationOptions, validate_batches
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
        self.assertEqual(self.errors_for(3, [lookup_entry(self.word_list, 1001)]), ())

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
        errors = self.errors_for(3, [lookup_entry(self.word_list, 1001, tier="quiz")])

        self.assertTrue(any("tier must be 'lookup'" in e for e in errors), errors)

    def test_pos_must_be_one_of_the_contract_values(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, pos="phrasal verb")])

        self.assert_one_error(errors, "pos 'phrasal verb'")

    def test_translations_must_be_cyrillic(self):
        errors = self.errors_for(1, [quiz_entry(self.word_list, 4, translations=["дом", "house"])])

        self.assert_one_error(errors, "translation 'house' must be Cyrillic")

    def test_translations_allow_spaces_hyphens_and_capitals(self):
        entry = quiz_entry(self.word_list, 5, translations=["понедельник", "что-нибудь", "в течение"])

        self.assertEqual(self.errors_for(1, [entry]), ())

    def test_quiz_tier_has_one_to_three_translations(self):
        too_many = quiz_entry(self.word_list, 4, translations=["дом", "здание", "жильё", "кров"])
        empty = quiz_entry(self.word_list, 3, translations=[])

        errors = self.errors_for(1, [empty, too_many])

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(all("1 to 3 translations" in e for e in errors))

    def test_lookup_tier_allows_up_to_five_translations(self):
        entry = lookup_entry(self.word_list, 1001, translations=["а", "б", "в", "г", "д"])

        self.assertEqual(self.errors_for(3, [entry]), ())

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

    def test_lookup_entry_must_not_carry_quiz_fields(self):
        entry = lookup_entry(self.word_list, 1001, example="Some example here.", synonym_group="be")

        errors = self.errors_for(3, [entry])

        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(all("unknown field" in e for e in errors))

    def test_quiz_entry_needs_a_synonym_group(self):
        entry = quiz_entry(self.word_list, 4)
        del entry["synonym_group"]

        self.assert_one_error(self.errors_for(1, [entry]), "missing field 'synonym_group'")


if __name__ == "__main__":
    unittest.main()
