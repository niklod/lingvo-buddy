"""The manual Wiktionary import: small extracts in, the text source out; and the download of the extracts."""

import gzip
import io
import json
import tempfile
import unittest
from pathlib import Path

from lingvo_dict.extended import importer
from lingvo_dict.extended.bundled import load_bundled
from lingvo_dict.extended.merge import EnglishEntry, RussianEntry
from lingvo_dict.extended.source import parse_source
from lingvo_dict.extended.validate import validate_extended
from tests.support import run_main

ENGLISH = [
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
RUWIKT = [{"word": "skedaddle", "lang_code": "en", "pos": "verb", "senses": [{"glosses": ["удирать"]}]}]
RUWORD = [
    {"word": "собака", "lang_code": "ru", "pos": "noun", "senses": [{"glosses": ["dog"]}]},
    {"word": "улепётывать", "lang_code": "ru", "pos": "verb", "senses": [{"glosses": ["to skedaddle"]}]},
]


def jsonl(entries):
    return "".join(json.dumps(entry, ensure_ascii=False) + "\n" for entry in entries)


class ImportTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.batches = self.folder / "batches"
        self.batches.mkdir()
        batch = {"entries": [{"headword": "dog", "translations": ["собака", "пёс"]}]}
        (self.batches / "batch-01.json").write_text(json.dumps(batch, ensure_ascii=False), encoding="utf-8")
        self.paths = {
            "en": self.folder / "en.jsonl.gz",
            "ruwikt": self.folder / "ruwikt.jsonl",
            "ruword": self.folder / "ruword.jsonl.gz",
        }
        self.paths["en"].write_bytes(gzip.compress(jsonl(ENGLISH).encode("utf-8")))
        self.paths["ruwikt"].write_text(jsonl(RUWIKT), encoding="utf-8")
        self.paths["ruword"].write_bytes(gzip.compress(jsonl(RUWORD).encode("utf-8")))
        self.out = self.folder / "extended.txt"

    def run_import(self):
        sources = [argument for key, path in self.paths.items() for argument in (f"--{key}", str(path))]
        return run_main(importer.main, *sources, "--batches", str(self.batches), "--out", str(self.out))

    def test_imports_the_three_extracts_into_a_deterministic_source(self):
        code, output, errors = self.run_import()

        self.assertEqual(code, 0, errors)
        data = parse_source(self.out.read_text(encoding="utf-8"))
        self.assertEqual(
            data.english,
            (
                EnglishEntry("petrichor", "noun", "/ˈpetrɪkɔː/", ("петрихор",), None, None),
                EnglishEntry("skedaddle", "verb", None, ("удирать",), None, None),
            ),
        )
        # «собака» is a bundled translation already; «улепетывать» is new.
        self.assertEqual(data.russian, (RussianEntry("улепетывать", ("skedaddle",)),))
        self.assertEqual(validate_extended(data, load_bundled(self.batches)), [])
        self.assertIn("2 English", output)

    def test_a_missing_extract_is_an_error_not_a_traceback(self):
        self.paths["ruwikt"] = self.folder / "absent.jsonl"

        code, _, errors = self.run_import()

        self.assertEqual(code, 2)
        self.assertIn("error:", errors)
        self.assertIn("absent.jsonl", errors)
        self.assertFalse(self.out.exists())

    def test_a_broken_json_line_names_the_file_and_the_line(self):
        self.paths["ruwikt"].write_text(jsonl(RUWIKT) + "{broken\n", encoding="utf-8")

        code, _, errors = self.run_import()

        self.assertEqual(code, 2)
        self.assertIn(f"error: {self.paths['ruwikt']}: line 2: invalid JSON", errors)

    def test_a_cut_gzip_extract_is_an_error(self):
        whole = gzip.compress(jsonl(RUWORD * 50).encode("utf-8"))
        self.paths["ruword"].write_bytes(whole[: len(whole) // 2])

        code, _, errors = self.run_import()

        self.assertEqual(code, 2)
        self.assertIn(f"error: {self.paths['ruword']}", errors)


class FakeResponse(io.BytesIO):
    def __init__(self, body, url="https://kaikki.org/file.jsonl", length=None, fail_after=None):
        super().__init__(body)
        self.url = url
        self.headers = {} if length is None else {"Content-Length": str(length)}
        self.fail_after = fail_after

    def geturl(self):
        return self.url

    def read(self, size=-1):
        if self.fail_after is not None and self.tell() >= self.fail_after:
            raise TimeoutError("the read timed out")
        return super().read(size if self.fail_after is None else min(size, self.fail_after))


class FetchTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.target = Path(folder.name) / "english.jsonl.gz"
        self.partial = Path(folder.name) / "english.jsonl.gz.part"
        self.calls = []

    def fetch(self, response):
        def opener(url, timeout):
            self.calls.append((url, timeout))
            return response

        importer.fetch("https://kaikki.org/file.jsonl", self.target, opener)

    def assert_nothing_written(self):
        self.assertEqual((self.target.exists(), self.partial.exists()), (False, False))

    def test_a_whole_download_lands_at_the_target_with_a_timeout(self):
        self.fetch(FakeResponse(b"data", length=4))

        self.assertEqual(self.target.read_bytes(), b"data")
        self.assertFalse(self.partial.exists())
        self.assertEqual(self.calls, [("https://kaikki.org/file.jsonl", importer.DOWNLOAD_TIMEOUT)])

    def test_a_download_without_content_length_is_kept(self):
        self.fetch(FakeResponse(b"data"))

        self.assertEqual(self.target.read_bytes(), b"data")

    def test_a_short_download_leaves_no_file(self):
        with self.assertRaisesRegex(importer.DownloadError, "stopped after 4 of 10 bytes"):
            self.fetch(FakeResponse(b"data", length=10))

        self.assert_nothing_written()

    def test_a_stopped_download_leaves_no_file(self):
        with self.assertRaises(TimeoutError):
            self.fetch(FakeResponse(b"data" * 10, length=40, fail_after=8))

        self.assert_nothing_written()

    def test_a_redirect_away_from_https_is_refused(self):
        with self.assertRaisesRegex(importer.DownloadError, "not https"):
            self.fetch(FakeResponse(b"data", url="http://kaikki.org/file.jsonl"))

        self.assert_nothing_written()

    def test_download_skips_extracts_the_folder_has(self):
        folder = self.target.parent
        for _, name in importer.DOWNLOADS.values():
            (folder / name).write_bytes(b"old")

        paths = importer.download(folder, opener=lambda *args, **kwargs: self.fail("must not download"))

        self.assertEqual(paths, {key: folder / name for key, (_, name) in importer.DOWNLOADS.items()})


if __name__ == "__main__":
    unittest.main()
