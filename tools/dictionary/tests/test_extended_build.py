"""The extended dictionary source, its validation and its SQLite build, all from small fixtures."""

import dataclasses
import gzip
import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from lingvo_dict.extended import build, importer
from lingvo_dict.extended.bundled import Bundled, load_bundled
from lingvo_dict.extended.merge import EnglishEntry, RussianEntry
from lingvo_dict.extended.source import SourceError, default_meta, parse_source, render_source
from lingvo_dict.extended.validate import validate_extended
from tests.support import run_main

PETRICHOR = EnglishEntry(
    "petrichor",
    "noun",
    "/ˈpetrɪkɔː/",
    ("петрихор",),
    "The petrichor rose after the storm.",
    "Запах земли поднялся после грозы.",
)
SKEDADDLE = EnglishEntry("skedaddle", "verb", None, ("улепётывать", "удирать"), None, None)
UDIRAT = RussianEntry("удирать", ("run away", "scarper"))
NONE = Bundled(frozenset(), frozenset())


class SourceTest(unittest.TestCase):
    def test_renders_sorted_deterministic_text_that_parses_back(self):
        text = render_source([SKEDADDLE, PETRICHOR], [UDIRAT], default_meta())
        shuffled = render_source([PETRICHOR, SKEDADDLE], [UDIRAT], dict(reversed(default_meta().items())))

        data = parse_source(text)

        self.assertEqual(text, shuffled)
        self.assertEqual(data.english, (PETRICHOR, SKEDADDLE))
        self.assertEqual(data.russian, (UDIRAT,))
        self.assertEqual(dict(data.meta), default_meta())

    def test_the_licence_note_names_wiktionary_cc_by_sa_and_the_changes(self):
        license_note = default_meta()["license"]

        for part in ("Wiktionary contributors", "CC BY-SA 4.0", "Modified"):
            self.assertIn(part, license_note)

    def test_a_malformed_line_names_its_number(self):
        with self.assertRaisesRegex(SourceError, "line 2"):
            parse_source("# license: x\nE\tonly\ttwo\n")


class ValidateTest(unittest.TestCase):
    def data(self, english=(PETRICHOR, SKEDADDLE), russian=(UDIRAT,), meta=None):
        return parse_source(render_source(english, russian, default_meta() if meta is None else meta))

    def errors(self, **kwargs):
        bundled = kwargs.pop("bundled", NONE)
        return validate_extended(self.data(**kwargs), bundled)

    def replaced(self, entry, **changes):
        return dataclasses.replace(entry, **changes)

    def test_valid_data_has_no_errors(self):
        self.assertEqual(self.errors(), [])

    def test_a_missing_licence_note_is_an_error(self):
        self.assertTrue(any("license" in error for error in self.errors(meta={"source": "x"})))

    def test_rejects_bad_fields(self):
        cases = {
            "pos": self.replaced(PETRICHOR, pos="thing"),
            "ipa": self.replaced(PETRICHOR, ipa="petrichor"),
            "translations": self.replaced(PETRICHOR, translations=()),
            "more than 5": self.replaced(PETRICHOR, translations=tuple("абвгде")),
            "at most 3 words": self.replaced(PETRICHOR, translations=("очень большой старый дом",)),
            "Russian letters": self.replaced(PETRICHOR, translations=("petrichor",)),
            "example": self.replaced(PETRICHOR, example="x" * 141),
            "Russian example without": self.replaced(SKEDADDLE, example_ru="Пример."),
            "headword": self.replaced(PETRICHOR, headword="Petrichor"),
        }
        for expected, entry in cases.items():
            with self.subTest(expected):
                errors = self.errors(english=(entry,))
                self.assertTrue(any(expected in error for error in errors), errors)

    def test_rejects_bad_russian_entries(self):
        for word, translations in (("Удирать", ("run",)), ("ёлка", ("tree",)), ("удирать", ()), ("удирать", ("бег",))):
            with self.subTest(word=word, translations=translations):
                self.assertTrue(self.errors(russian=(RussianEntry(word, translations),)))

    def test_rejects_words_the_bundled_dictionary_has(self):
        bundled = Bundled(frozenset({"petrichor"}), frozenset({"удирать"}))

        errors = self.errors(bundled=bundled)

        self.assertEqual(len(errors), 2, errors)

    def test_rejects_unsorted_and_duplicate_entries(self):
        unsorted = parse_source(
            "# license: x\nE\tzeta\tnoun\t\tслово\t\t\nE\talpha\tnoun\t\tслово\t\t\nE\talpha\tnoun\t\tслово\t\t\n"
        )

        errors = validate_extended(unsorted, NONE)

        self.assertEqual(len(errors), 2, errors)


class BuildTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.source = self.folder / "extended.txt"
        self.out = self.folder / "out" / "extended.sqlite"
        self.batches = self.folder / "batches"
        self.batches.mkdir()

    def build(self, text=None, *args):
        self.source.write_text(
            text or render_source([SKEDADDLE, PETRICHOR], [UDIRAT], default_meta()), encoding="utf-8"
        )
        return run_main(
            build.main, "--source", str(self.source), "--out", str(self.out), "--batches", str(self.batches), *args
        )

    def query(self, sql):
        with closing(sqlite3.connect(self.out)) as connection:
            return connection.execute(sql).fetchall()

    def test_builds_the_english_and_russian_tables_with_licence_meta(self):
        code, output, errors = self.build()

        self.assertEqual(code, 0, errors)
        self.assertIn("2 English", output)
        self.assertEqual(
            self.query("SELECT headword, pos, ipa, translations, example, example_ru FROM english ORDER BY headword"),
            [
                ("petrichor", "noun", "/ˈpetrɪkɔː/", "петрихор", PETRICHOR.example, PETRICHOR.example_ru),
                ("skedaddle", "verb", None, "улепётывать|удирать", None, None),
            ],
        )
        self.assertEqual(self.query("SELECT word, translations FROM russian"), [("удирать", "run away|scarper")])
        self.assertEqual(self.query("SELECT value FROM meta WHERE key = 'license'"), [(default_meta()["license"],)])
        self.assertEqual(self.query("PRAGMA user_version"), [(build.SCHEMA_VERSION,)])
        self.assertEqual(self.query("PRAGMA journal_mode"), [("delete",)])

    def test_the_same_source_gives_the_same_file(self):
        self.build()
        first = self.out.read_bytes()
        self.build()

        self.assertEqual(self.out.read_bytes(), first)

    def test_invalid_data_stops_the_build_and_leaves_no_file(self):
        bad = self.folder / "bad.txt"
        bad.write_text("# license: x\nE\tBad\tnoun\t\tслово\t\t\n", encoding="utf-8")

        code, _, errors = self.build(bad.read_text(encoding="utf-8"))

        self.assertEqual(code, 1)
        self.assertIn("headword", errors)
        self.assertFalse(self.out.exists())

    def test_a_word_of_the_bundled_batches_stops_the_build(self):
        batch = {"entries": [{"headword": "petrichor", "translations": ["запах"]}]}
        (self.batches / "batch-01.json").write_text(json.dumps(batch, ensure_ascii=False), encoding="utf-8")

        code, _, errors = self.build()

        self.assertEqual(code, 1)
        self.assertIn("petrichor", errors)


class ImportTest(unittest.TestCase):
    def test_imports_the_three_extracts_into_a_deterministic_source(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            batches = folder / "batches"
            batches.mkdir()
            batch = {"entries": [{"headword": "dog", "translations": ["собака", "пёс"]}]}
            (batches / "batch-01.json").write_text(json.dumps(batch, ensure_ascii=False), encoding="utf-8")
            english = [
                {
                    "word": "dog",
                    "lang_code": "en",
                    "pos": "noun",
                    "senses": [{"glosses": ["x"]}],
                    "translations": [{"lang_code": "ru", "word": "собака"}],
                },
                {
                    "word": "petrichor",
                    "lang_code": "en",
                    "pos": "noun",
                    "senses": [{"glosses": ["x"]}],
                    "translations": [{"lang_code": "ru", "word": "пе́трихор"}],
                    "sounds": [{"ipa": "/ˈpɛt.ɹɪ.kɔː/"}],
                },
            ]
            ruwikt = [{"word": "skedaddle", "lang_code": "en", "pos": "verb", "senses": [{"glosses": ["удирать"]}]}]
            ruword = [
                {"word": "собака", "lang_code": "ru", "pos": "noun", "senses": [{"glosses": ["dog"]}]},
                {"word": "улепётывать", "lang_code": "ru", "pos": "verb", "senses": [{"glosses": ["to skedaddle"]}]},
            ]
            paths = {}
            for key, entries, gzipped in (("en", english, True), ("ruwikt", ruwikt, False), ("ruword", ruword, True)):
                path = folder / (key + (".jsonl.gz" if gzipped else ".jsonl"))
                payload = "\n".join(json.dumps(entry, ensure_ascii=False) for entry in entries) + "\n"
                if gzipped:
                    path.write_bytes(gzip.compress(payload.encode("utf-8")))
                else:
                    path.write_text(payload, encoding="utf-8")
                paths[key] = str(path)
            out = folder / "extended.txt"

            code, output, errors = run_main(
                importer.main,
                "--en", paths["en"], "--ruwikt", paths["ruwikt"], "--ruword", paths["ruword"],
                "--batches", str(batches), "--out", str(out),
            )  # fmt: skip

            self.assertEqual(code, 0, errors)
            data = parse_source(out.read_text(encoding="utf-8"))
            self.assertEqual([entry.headword for entry in data.english], ["petrichor", "skedaddle"])
            self.assertEqual(data.english[0].translations, ("петрихор",))
            self.assertEqual(data.english[0].ipa, "/ˈpetrɪkɔː/")
            self.assertEqual(data.english[1].translations, ("удирать",))
            # «собака» is a bundled translation already; «улепетывать» is new.
            self.assertEqual(
                [(entry.word, entry.translations) for entry in data.russian], [("улепетывать", ("skedaddle",))]
            )
            self.assertEqual(validate_extended(data, load_bundled(batches)), [])
            self.assertIn("2 English", output)


if __name__ == "__main__":
    unittest.main()
