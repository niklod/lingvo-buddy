"""Reading kaikki entries and merging the three Wiktionary extracts into extended entries."""

import json
import unittest

from lingvo_dict.extended.merge import merge_english, merge_russian
from lingvo_dict.extended.records import english_records, russian_wiktionary_records, russian_word_records


def lines(*entries):
    return [json.dumps(entry, ensure_ascii=False) for entry in entries]


def english_entry(word, pos="noun", translations=(), senses=None, sounds=(), lang_code="en"):
    return {
        "word": word,
        "pos": pos,
        "lang_code": lang_code,
        "sounds": list(sounds),
        "senses": senses if senses is not None else [{"glosses": ["a thing"]}],
        "translations": [{"lang_code": "ru", "word": text} for text in translations],
    }


class EnglishRecordsTest(unittest.TestCase):
    def read(self, *entries, skip=frozenset()):
        return list(english_records(lines(*entries), skip))

    def test_keeps_russian_translations_of_the_entry_and_of_its_senses(self):
        entry = english_entry("skedaddle", "verb", ["улепётывать"])
        entry["senses"] = [{"glosses": ["to run"], "translations": [{"lang_code": "ru", "word": "удирать"}]}]

        (record,) = self.read(entry)

        self.assertEqual(record.translations, ("улепётывать", "удирать"))
        self.assertEqual(record.pos, "verb")

    def test_ignores_other_languages_and_obsolete_translations(self):
        entry = english_entry("dog", translations=["собака"])
        entry["translations"] += [
            {"lang_code": "de", "word": "Hund"},
            {"lang_code": "ru", "word": "пёс", "tags": ["obsolete"]},
        ]

        (record,) = self.read(entry)

        self.assertEqual(record.translations, ("собака",))

    def test_translations_are_not_checked_for_gloss_junk(self):
        (record,) = self.read(english_entry("form", translations=["форма"]))

        self.assertEqual(record.translations, ("форма",))

    def test_skips_other_languages_phrases_names_and_capitalised_words(self):
        records = self.read(
            english_entry("chien", lang_code="fr"),
            english_entry("ice cream"),
            english_entry("Paris", pos="name"),
            english_entry("Monday"),
            english_entry("etc.", pos="abbrev"),
            english_entry("a", "numeral"),
            english_entry("kept"),
        )

        self.assertEqual([record.word for record in records], ["kept"])

    def test_skips_words_the_bundled_dictionary_has(self):
        self.assertEqual(self.read(english_entry("dog"), skip={"dog"}), [])

    def test_skips_inflected_and_alternative_forms(self):
        entry = english_entry("dogs", senses=[{"glosses": ["plural of dog"], "form_of": [{"word": "dog"}]}])
        alternative = english_entry("colour", senses=[{"glosses": ["x"], "tags": ["alt-of"]}])

        self.assertEqual(self.read(entry, alternative), [])

    def test_a_word_with_a_form_sense_and_a_real_sense_stays(self):
        senses = [{"glosses": ["plural of x"], "form_of": [{"word": "x"}]}, {"glosses": ["a real meaning"]}]

        self.assertEqual(len(self.read(english_entry("axes", senses=senses))), 1)

    def test_takes_ipa_and_a_usage_example_from_the_entry(self):
        senses = [
            {
                "glosses": ["to run"],
                "examples": [
                    {"text": "A long quotation here.", "type": "quotation", "ref": "1895"},
                    {"text": "They skedaddled at dawn.", "type": "example"},
                ],
            }
        ]
        sounds = [{"ipa": "/skɪˈdæd.l̩/", "tags": ["Received-Pronunciation"]}]

        (record,) = self.read(english_entry("skedaddle", "verb", senses=senses, sounds=sounds))

        self.assertEqual(record.ipa, "/skɪˈdædl/")
        self.assertEqual(record.example, ("They skedaddled at dawn.", ""))

    def test_maps_the_wiktionary_part_of_speech(self):
        (adjective, other) = self.read(english_entry("big", "adj"), english_entry("hmm", "particle"))

        self.assertEqual((adjective.pos, other.pos), ("adjective", "other"))


class RussianWiktionaryRecordsTest(unittest.TestCase):
    def test_turns_russian_glosses_into_translations_and_keeps_the_translated_example(self):
        entry = english_entry(
            "codswallop",
            senses=[
                {
                    "glosses": ["разг. чепуха, ерунда, ахинея; абсурд"],
                    "examples": [{"text": "What codswallop!", "translation": "Какая чепуха!"}],
                }
            ],
        )

        (record,) = russian_wiktionary_records(lines(entry), frozenset())

        self.assertEqual(record.translations, ("чепуха", "ерунда", "ахинея", "абсурд"))
        self.assertEqual(record.example, ("What codswallop!", "Какая чепуха!"))
        self.assertIsNone(record.ipa)

    def test_a_long_definition_gives_no_translation(self):
        entry = english_entry("petrichor", senses=[{"glosses": ["запах земли после дождя в сухую погоду"]}])

        (record,) = russian_wiktionary_records(lines(entry), frozenset())

        self.assertEqual(record.translations, ())


class RussianWordRecordsTest(unittest.TestCase):
    def read(self, *entries):
        return list(russian_word_records(lines(*entries)))

    def test_takes_english_glosses_of_russian_words(self):
        entry = english_entry("улепётывать", "verb", senses=[{"glosses": ["to scarper, to skedaddle"]}], lang_code="ru")

        (record,) = self.read(entry)

        self.assertEqual((record.key, record.translations), ("улепетывать", ("scarper", "skedaddle")))

    def test_skips_forms_names_and_words_that_are_not_plain_russian(self):
        records = self.read(
            english_entry(
                "собаки", senses=[{"glosses": ["genitive of собака"], "form_of": [{"word": "собака"}]}], lang_code="ru"
            ),
            english_entry("Москва", "name", senses=[{"glosses": ["Moscow"]}], lang_code="ru"),
            english_entry("кто-либо", senses=[{"glosses": ["someone"]}], lang_code="ru"),
            english_entry("dog", senses=[{"glosses": ["dog"]}], lang_code="ru"),
            english_entry("pies", senses=[{"glosses": ["dog"]}], lang_code="pl"),
        )

        self.assertEqual([record.key for record in records], ["кто-либо"])


class MergeEnglishTest(unittest.TestCase):
    def merge(self, english, russian=()):
        return merge_english(
            english_records(lines(*english), frozenset()),
            russian_wiktionary_records(lines(*russian), frozenset()),
        )

    def test_english_wiktionary_translations_come_first_then_russian_wiktionary_glosses(self):
        english = [english_entry("skedaddle", "verb", ["улепётывать", "удирать"])]
        russian = [english_entry("skedaddle", "verb", senses=[{"glosses": ["удирать; смываться"]}])]

        (entry,) = self.merge(english, russian)

        self.assertEqual(entry.translations, ("улепётывать", "удирать", "смываться"))

    def test_keeps_five_translations_at_most(self):
        words = ["один", "два", "три", "четыре", "пять", "шесть", "семь"]

        (entry,) = self.merge([english_entry("number", translations=words)])

        self.assertEqual(entry.translations, tuple(words[:5]))

    def test_translations_come_from_the_main_part_of_speech_only(self):
        english = [english_entry("rank", "noun", ["ранг"]), english_entry("rank", "verb", ["ранжировать"])]

        (entry,) = self.merge(english)

        self.assertEqual((entry.pos, entry.translations), ("noun", ("ранг",)))

    def test_a_word_without_any_translation_is_dropped(self):
        self.assertEqual(self.merge([english_entry("mumpsimus")]), [])

    def test_a_russian_wiktionary_example_with_translation_wins(self):
        english = [
            english_entry(
                "abuse",
                "noun",
                ["злоупотребление"],
                senses=[{"glosses": ["x"], "examples": [{"text": "An English one.", "type": "example"}]}],
            )
        ]
        russian = [
            english_entry(
                "abuse",
                "noun",
                senses=[
                    {
                        "glosses": ["x"],
                        "examples": [{"text": "Drug abuse.", "translation": "Злоупотребление наркотиками."}],
                    }
                ],
            )
        ]

        (entry,) = self.merge(english, russian)

        self.assertEqual((entry.example, entry.example_ru), ("Drug abuse.", "Злоупотребление наркотиками."))

    def test_ipa_comes_from_english_wiktionary(self):
        sounds = [{"ipa": "/ˈpɛt.ɹɪˌkɔː/"}]

        (entry,) = self.merge([english_entry("petrichor", translations=["петрихор"], sounds=sounds)])

        self.assertEqual(entry.ipa, "/ˈpetrɪˌkɔː/")

    def test_entries_are_sorted_by_headword(self):
        english = [english_entry(word, translations=["слово"]) for word in ("zeta", "alpha", "mid")]

        self.assertEqual([entry.headword for entry in self.merge(english)], ["alpha", "mid", "zeta"])


class MergeRussianTest(unittest.TestCase):
    def merge(self, *entries, bundled=frozenset()):
        return merge_russian(russian_word_records(lines(*entries)), bundled)

    def test_unions_the_glosses_of_all_entries_of_a_word_and_keeps_five(self):
        noun = english_entry("замок", senses=[{"glosses": ["castle, palace"]}], lang_code="ru")
        verb = english_entry("замок", "verb", senses=[{"glosses": ["lock; latch, bolt, bar"]}], lang_code="ru")

        (entry,) = self.merge(noun, verb)

        self.assertEqual(entry.translations, ("castle", "palace", "lock", "latch", "bolt"))

    def test_words_the_bundled_translations_have_are_dropped_ignoring_yo(self):
        entry = english_entry("ёлка", senses=[{"glosses": ["fir tree"]}], lang_code="ru")

        self.assertEqual(self.merge(entry, bundled=frozenset({"елка"})), [])

    def test_a_word_without_translation_is_dropped_and_the_rest_is_sorted(self):
        entries = [
            english_entry("яблоко", senses=[{"glosses": ["apple"]}], lang_code="ru"),
            english_entry("арбуз", senses=[{"glosses": ["watermelon"]}], lang_code="ru"),
            english_entry("ничто", senses=[{"glosses": ["a very long gloss of many words here"]}], lang_code="ru"),
        ]

        self.assertEqual([entry.word for entry in self.merge(*entries)], ["арбуз", "яблоко"])


if __name__ == "__main__":
    unittest.main()
