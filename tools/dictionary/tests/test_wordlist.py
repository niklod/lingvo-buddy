import unittest

from lingvo_dict.wordlist import ExportRules, rank_lemmas, rank_lemmas_in_stages

LEMMAS = {
    "was": "be",
    "is": "be",
    "be": "be",
    "said": "say",
    "say": "say",
    "house": "house",
    "houses": "house",
    "john": "John",
    "monday": "Monday",
    "the": "the",
    "fuck": "fuck",
    "felt": "felt",
    "feel": "feel",
    "cat": "cat",
    "dog": "dog",
}


def fake_lemmatize(form):
    return LEMMAS.get(form)


def rules(exclusions=(), keep=(), overrides=None):
    return ExportRules(
        exclusions=frozenset(exclusions),
        keep=frozenset(keep),
        lemma_overrides=dict(overrides or {}),
    )


def headwords(result):
    return [(w.rank, w.headword) for w in result.words]


class RankLemmasTest(unittest.TestCase):
    def test_inflected_forms_add_their_frequency_to_the_lemma(self):
        forms = [("said", 0.5), ("cat", 0.6), ("say", 0.2), ("dog", 0.65)]

        result = rank_lemmas(forms, fake_lemmatize, rules(), limit=10)

        self.assertEqual(headwords(result), [(1, "say"), (2, "dog"), (3, "cat")])

    def test_limit_cuts_the_list_after_the_given_number_of_lemmas(self):
        forms = [("dog", 0.9), ("cat", 0.8), ("house", 0.7)]

        result = rank_lemmas(forms, fake_lemmatize, rules(), limit=2)

        self.assertEqual(headwords(result), [(1, "dog"), (2, "cat")])

    def test_equal_frequencies_are_ordered_alphabetically(self):
        forms = [("dog", 0.5), ("cat", 0.5)]

        result = rank_lemmas(forms, fake_lemmatize, rules(), limit=10)

        self.assertEqual(headwords(result), [(1, "cat"), (2, "dog")])

    def test_exclusion_list_removes_lemmas_with_all_their_forms(self):
        forms = [("the", 0.9), ("was", 0.8), ("is", 0.7), ("cat", 0.1)]

        result = rank_lemmas(
            forms, fake_lemmatize, rules(exclusions=["the", "be"]), limit=10
        )

        self.assertEqual(headwords(result), [(1, "cat")])
        self.assertEqual(
            [(e.lemma, e.reason) for e in result.excluded],
            [("be", "exclusion-list"), ("the", "exclusion-list")],
        )

    def test_tokens_with_digits_apostrophes_or_one_letter_are_dropped(self):
        forms = [("2010", 0.9), ("it's", 0.8), ("s", 0.7), ("cat", 0.1)]

        result = rank_lemmas(forms, fake_lemmatize, rules(), limit=10)

        self.assertEqual(headwords(result), [(1, "cat")])
        self.assertEqual(
            [(e.lemma, e.reason) for e in result.excluded],
            [("2010", "not-a-word"), ("it's", "not-a-word"), ("s", "single-letter")],
        )

    def test_capitalized_lemmas_are_dropped_as_proper_nouns(self):
        forms = [("john", 0.9), ("cat", 0.1)]

        result = rank_lemmas(forms, fake_lemmatize, rules(), limit=10)

        self.assertEqual(headwords(result), [(1, "cat")])
        self.assertEqual(result.excluded[0].reason, "proper-noun")

    def test_the_most_frequent_form_decides_that_a_lemma_is_a_proper_noun(self):
        forms = [("john", 0.9), ("johns", 0.2), ("cat", 0.1)]

        result = rank_lemmas(
            forms, lambda form: {"johns": "john"}.get(form) or fake_lemmatize(form), rules(), limit=10
        )

        self.assertEqual(headwords(result), [(1, "cat")])

    def test_a_lemma_of_one_letter_is_dropped(self):
        forms = [("ss", 0.9), ("cat", 0.1)]

        result = rank_lemmas(forms, lambda form: {"ss": "s"}.get(form) or fake_lemmatize(form), rules(), limit=10)

        self.assertEqual(headwords(result), [(1, "cat")])

    def test_exclusion_list_also_drops_a_single_form_of_another_lemma(self):
        forms = [("united", 0.9), ("cat", 0.5), ("unite", 0.2)]

        result = rank_lemmas(
            forms,
            lambda form: {"united": "unite", "unite": "unite"}.get(form) or fake_lemmatize(form),
            rules(exclusions=["united"]),
            limit=10,
        )

        self.assertEqual(headwords(result), [(1, "cat"), (2, "unite")])

    def test_keep_list_keeps_a_capitalized_lemma_with_its_case(self):
        forms = [("monday", 0.9), ("cat", 0.1)]

        result = rank_lemmas(forms, fake_lemmatize, rules(keep=["Monday"]), limit=10)

        self.assertEqual(headwords(result), [(1, "Monday"), (2, "cat")])

    def test_words_unknown_to_the_lemmatizer_are_dropped_unless_kept(self):
        forms = [("lol", 0.9), ("her", 0.8), ("cat", 0.1)]

        result = rank_lemmas(forms, fake_lemmatize, rules(keep=["her"]), limit=10)

        self.assertEqual(headwords(result), [(1, "her"), (2, "cat")])
        self.assertEqual([(e.lemma, e.reason) for e in result.excluded], [("lol", "unknown-word")])

    def test_lemma_override_replaces_the_lemmatizer_result(self):
        forms = [("felt", 0.5), ("feel", 0.2), ("cat", 0.6)]

        result = rank_lemmas(
            forms, fake_lemmatize, rules(overrides={"felt": "feel"}), limit=10
        )

        self.assertEqual(headwords(result), [(1, "feel"), (2, "cat")])

    def test_lemma_override_also_folds_a_lemma_into_another_lemma(self):
        forms = [("centres", 0.5), ("centre", 0.2), ("center", 0.4), ("cat", 0.6)]

        result = rank_lemmas(
            forms,
            lambda form: {"centres": "centre", "centre": "centre", "center": "center"}.get(form)
            or fake_lemmatize(form),
            rules(overrides={"centre": "center"}),
            limit=10,
        )

        self.assertEqual(headwords(result), [(1, "center"), (2, "cat")])

    def test_report_lists_only_exclusions_frequent_enough_to_rank(self):
        forms = [("the", 0.9), ("cat", 0.5), ("dog", 0.4), ("fuck", 0.3)]

        result = rank_lemmas(
            forms, fake_lemmatize, rules(exclusions=["the", "fuck"]), limit=2
        )

        self.assertEqual([e.lemma for e in result.excluded], ["the"])



class RankLemmasInStagesTest(unittest.TestCase):
    # "houses" lifts "house" above "dog" once the second stage reads it.
    FORMS = [("dog", 0.5), ("cat", 0.4), ("house", 0.3), ("houses", 0.25), ("say", 0.2)]

    def test_a_later_stage_appends_new_lemmas_and_keeps_the_earlier_order(self):
        result = rank_lemmas_in_stages(self.FORMS, fake_lemmatize, rules(), limit=10, stages=(3, 5))

        self.assertEqual(headwords(result), [(1, "dog"), (2, "cat"), (3, "house"), (4, "say")])

    def test_one_stage_with_every_form_ranks_like_rank_lemmas(self):
        staged = rank_lemmas_in_stages(self.FORMS, fake_lemmatize, rules(), limit=10, stages=(5,))
        single = rank_lemmas(self.FORMS, fake_lemmatize, rules(), limit=10)

        self.assertEqual(staged, single)

    def test_limit_cuts_the_list_inside_a_later_stage(self):
        result = rank_lemmas_in_stages(self.FORMS, fake_lemmatize, rules(), limit=3, stages=(2, 5))

        self.assertEqual(headwords(result), [(1, "dog"), (2, "cat"), (3, "house")])

    def test_the_report_uses_the_frequencies_of_every_form(self):
        # The first stage alone ranks one lemma, so "the" would look frequent enough to rank.
        forms = [("cat", 0.5), ("the", 0.3), ("house", 0.2), ("houses", 0.2)]

        result = rank_lemmas_in_stages(
            forms, fake_lemmatize, rules(exclusions=["the"]), limit=2, stages=(2, 4)
        )

        self.assertEqual(headwords(result), [(1, "cat"), (2, "house")])
        self.assertEqual(result.excluded, ())

    def test_stages_must_grow(self):
        with self.assertRaisesRegex(ValueError, "stages must grow"):
            rank_lemmas_in_stages(self.FORMS, fake_lemmatize, rules(), limit=3, stages=(5, 3))


if __name__ == "__main__":
    unittest.main()
