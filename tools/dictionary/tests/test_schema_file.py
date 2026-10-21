import unittest

from lingvo_dict.schema_file import SCHEMA_FILE, render_schema


class SchemaFileTest(unittest.TestCase):
    def test_committed_schema_matches_the_contract(self):
        self.assertEqual(
            SCHEMA_FILE.read_text(encoding="utf-8"),
            render_schema(),
            "batch.schema.json is stale: run python3 tools/dictionary/write_schema.py",
        )


if __name__ == "__main__":
    unittest.main()
