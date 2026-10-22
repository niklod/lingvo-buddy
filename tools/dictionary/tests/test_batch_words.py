"""batch_words.py on the committed word list: the ranks a batch generator must cover."""

import unittest

import batch_words
from tests.support import run_main


class BatchWordsTest(unittest.TestCase):
    def test_prints_rank_headword_and_tier_for_each_rank_of_the_batch(self):
        code, out, _ = run_main(batch_words.main, "batch-02")

        lines = out.splitlines()
        self.assertEqual(code, 0)
        self.assertEqual(len(lines), 500)
        self.assertTrue(lines[0].startswith("501\t"), lines[0])
        self.assertEqual(lines[-1], "1000\tcrime\tquiz")

    def test_top_2000_batches_print_the_quiz_tier(self):
        code, out, _ = run_main(batch_words.main, "batch-04")

        self.assertEqual(code, 0)
        self.assertTrue(out.splitlines()[-1].startswith("2000\t"))
        self.assertTrue(out.splitlines()[-1].endswith("\tquiz"))

    def test_lookup_batches_print_the_lookup_tier(self):
        code, out, _ = run_main(batch_words.main, "batch-05")

        self.assertEqual(code, 0)
        self.assertTrue(out.splitlines()[0].startswith("2001\t"))
        self.assertTrue(out.splitlines()[0].endswith("\tlookup"))

    def test_bad_batch_ids_exit_two_with_the_usage(self):
        for argv in (["batch-1"], ["batch-21"], ["batch-00"], [], ["batch-01", "batch-02"]):
            with self.subTest(argv=argv):
                code, _, err = run_main(batch_words.main, *argv)

                self.assertEqual(code, 2)
                self.assertIn("usage: batch_words.py batch-NN (01 to 20)", err)


if __name__ == "__main__":
    unittest.main()
