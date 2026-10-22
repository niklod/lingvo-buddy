import unittest

from lingvo_dict.russian_text import normalized


class RussianTextTest(unittest.TestCase):
    def test_normalizes_like_lingvo_core(self):
        # The same cases as RussianText.normalized in LingvoCore; `lingvo-dict check` compares the real data.
        cases = {" Ещё \n": "еще", "ЁЛКА": "елка", "сомнение": "сомнение", "Нью-Йорк": "нью-йорк"}

        self.assertEqual({text: normalized(text) for text in cases}, cases)
