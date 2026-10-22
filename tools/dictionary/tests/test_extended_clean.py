"""The cleaning rules that turn raw Wiktionary glosses, IPA and examples into extended dictionary data."""

import unittest

from lingvo_dict.extended.clean import (
    english_items,
    normalize_ipa,
    pick_example,
    pick_ipa,
    russian_items,
    russian_translation_items,
    strip_labels,
    strip_stress,
)


class StressAndLabelTest(unittest.TestCase):
    def test_strips_stress_marks_but_keeps_yo_and_short_i(self):
        self.assertEqual(strip_stress("пе\u0301трихо\u0301р"), "петрихор")
        self.assertEqual(strip_stress("ёлка и йогурт"), "ёлка и йогурт")

    def test_strips_leading_domain_labels(self):
        self.assertEqual(strip_labels("муз. лад"), "лад")
        self.assertEqual(strip_labels("разг., прост. чепуха"), "чепуха")
        self.assertEqual(strip_labels("хим. соль"), "соль")

    def test_keeps_text_without_a_label(self):
        self.assertEqual(strip_labels("чепуха"), "чепуха")
        self.assertEqual(strip_labels("и т. д."), "и т. д.")


class RussianItemsTest(unittest.TestCase):
    def test_splits_a_gloss_on_commas_and_semicolons_after_removing_labels(self):
        self.assertEqual(
            russian_items("разг. чепуха, ерунда, ахинея; абсурд"), ["чепуха", "ерунда", "ахинея", "абсурд"]
        )

    def test_removes_parenthetical_text(self):
        self.assertEqual(russian_items("запах (после дождя), аромат"), ["запах", "аромат"])

    def test_labels_inside_a_gloss_go_too(self):
        self.assertEqual(russian_items("чепуха; прост. ахинея"), ["чепуха", "ахинея"])

    def test_keeps_items_of_at_most_three_words(self):
        self.assertEqual(russian_items("очень большой дом, самый большой старый дом"), ["очень большой дом"])

    def test_drops_variant_and_form_glosses(self):
        for gloss in (
            "вариант слова собака",
            "то же, что собака",
            "форма множественного числа от «собака»",
            "уменьшительное от собака",
            "сокр. от «собака»",
            "устаревшее написание слова собака",
        ):
            with self.subTest(gloss=gloss):
                self.assertEqual(russian_items(gloss), [])

    def test_drops_items_with_latin_letters_digits_or_symbols(self):
        self.assertEqual(russian_items("собака, dog, 12, кот/кошка"), ["собака"])

    def test_strips_stress_marks_and_trailing_dots(self):
        self.assertEqual(russian_items("пе\u0301трихор."), ["петрихор"])

    def test_dedupes_ignoring_case(self):
        self.assertEqual(russian_items("Кот, кот"), ["Кот"])


class TranslationRowTest(unittest.TestCase):
    def test_a_row_is_one_translation_without_stress_and_parentheses(self):
        self.assertEqual(russian_translation_items("пе́трихор (редкое)"), ["петрихор"])

    def test_a_row_with_a_comma_is_a_clause_and_gives_nothing(self):
        self.assertEqual(russian_translation_items("болезнь, вызванная паразитом"), [])

    def test_a_row_keeps_words_that_look_like_form_glosses(self):
        self.assertEqual(russian_translation_items("форма"), ["форма"])


class EnglishItemsTest(unittest.TestCase):
    def test_splits_and_drops_the_infinitive_marker_and_parentheses(self):
        self.assertEqual(english_items("to scarper, to skedaddle (to quickly run away)"), ["scarper", "skedaddle"])

    def test_drops_articles(self):
        self.assertEqual(english_items("a nonsense; the rubbish"), ["nonsense", "rubbish"])

    def test_drops_form_and_variant_glosses(self):
        for gloss in (
            "plural of dog",
            "alternative form of dog",
            "genitive singular of dog",
            "obsolete spelling of dog",
            "inflection of dog",
            "diminutive of dog",
        ):
            with self.subTest(gloss=gloss):
                self.assertEqual(english_items(gloss), [])

    def test_keeps_items_of_at_most_three_words(self):
        self.assertEqual(english_items("ice cream, very long winded phrase"), ["ice cream"])

    def test_drops_items_with_digits_or_foreign_letters(self):
        self.assertEqual(english_items("dog, 2nd, naïve"), ["dog"])


class IpaTest(unittest.TestCase):
    def test_removes_syllable_dots_and_uses_the_bundled_symbols(self):
        self.assertEqual(normalize_ipa("/ˈpɛt.ɹɪ.kɔː/"), "/ˈpetrɪkɔː/")
        self.assertEqual(normalize_ipa("/ɡa.lɪˈmɔː.fɹi/"), "/ɡalɪˈmɔːfri/")
        self.assertEqual(normalize_ipa("/skɪˈdædɫ̩/"), "/skɪˈdædl/")

    def test_unifies_the_g_and_the_affricates(self):
        self.assertEqual(normalize_ipa("/gʧʤ/"), "/ɡtʃdʒ/")
        self.assertEqual(normalize_ipa("/t͡ʃɪp/"), "/tʃɪp/")

    def test_maps_american_r_coloured_vowels(self):
        self.assertEqual(normalize_ipa("/ˈwɔtɚ/"), "/ˈwɔtə/")

    def test_rejects_symbols_outside_the_bundled_style(self):
        self.assertIsNone(normalize_ipa("/ʁɛ/"))
        self.assertIsNone(normalize_ipa("[ˈpɛtɹɪkə]"))
        self.assertIsNone(normalize_ipa("/ /"))

    def test_picks_the_british_transcription_first(self):
        sounds = [
            {"ipa": "/ˈkɑdzwɑləp/", "tags": ["General-American"]},
            {"ipa": "/ˈkɒdzwɒləp/", "tags": ["Received-Pronunciation"]},
            {"audio": "x.ogg"},
        ]
        self.assertEqual(pick_ipa(sounds), "/ˈkɒdzwɒləp/")

    def test_repairs_a_fragment_that_the_template_split(self):
        sounds = [
            {"tags": ["Received-Pronunciation"], "ipa": "/ˈpɛt.ɹɪ.kə"},
            {"tags": ["Received-Pronunciation"], "ipa": "-ˌkɔː/"},
        ]
        self.assertEqual(pick_ipa(sounds), "/ˈpetrɪkə/")

    def test_prefers_a_whole_transcription_over_a_repaired_fragment(self):
        sounds = [{"ipa": "/ˈabc"}, {"ipa": "/ˈdef/", "tags": ["US"]}]
        self.assertEqual(pick_ipa(sounds), "/ˈdef/")

    def test_no_usable_transcription_gives_none(self):
        self.assertIsNone(pick_ipa([{"audio": "x.ogg"}, {"ipa": "[ˈpɛtɹɪkə]"}]))


class ExampleTest(unittest.TestCase):
    def test_takes_a_short_example_and_not_a_quotation(self):
        examples = [
            {"text": "A long quotation from a novel.", "type": "quotation", "ref": "1895, Crane"},
            {"text": "They skedaddled at dawn.", "type": "example"},
        ]
        self.assertEqual(pick_example(examples), ("They skedaddled at dawn.", ""))

    def test_rejects_untyped_citations_and_cited_examples(self):
        examples = [
            {"text": "1993, J. Neville Turner, The One-Day Game"},
            {"text": "Looks like an example.", "type": "example", "ref": "1999, Somebody"},
        ]
        self.assertIsNone(pick_example(examples))

    def test_rejects_long_and_multiline_examples(self):
        examples = [{"text": "word " * 40, "type": "example"}, {"text": "A:\nB", "type": "example"}]
        self.assertIsNone(pick_example(examples))

    def test_keeps_the_russian_translation_when_the_source_has_one(self):
        examples = [{"text": "Drug abuse.", "translation": "Злоупотребление наркотиками."}]
        self.assertEqual(pick_example(examples, translated=True), ("Drug abuse.", "Злоупотребление наркотиками."))

    def test_translated_examples_must_have_the_translation(self):
        self.assertIsNone(pick_example([{"text": "Drug abuse."}], translated=True))

    def test_rejects_fragments_that_are_no_sentence(self):
        examples = [
            {"text": "genuinely surprised", "type": "example"},
            {"text": "an undressed wound", "type": "example"},
        ]
        self.assertIsNone(pick_example(examples))

    def test_collapses_whitespace(self):
        self.assertEqual(pick_example([{"text": " Go   away. ", "type": "example"}]), ("Go away.", ""))


if __name__ == "__main__":
    unittest.main()
