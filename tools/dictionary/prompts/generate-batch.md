# Generate one dictionary batch

You write one batch of the LingvoBuddy bundled dictionary: English headwords with Russian translations.
Replace `{{BATCH}}` with the batch id you were given (`batch-01` … `batch-60`).
Run all commands from the repository root. They need only `python3` (3.9 or later), no packages.

## Scope

- `batch-NN` covers ranks `(NN-1)*500+1` to `NN*500`: `batch-01` = 1–500, `batch-02` = 501–1000, `batch-60` = 29501–30000.
- Ranks 1–2000 are the **quiz tier** (`batch-01` to `batch-04`: Top-1000 and Top-2000). Ranks 2001–30000 are the **lookup tier**.
- `example` and `example_ru` are required for every entry of both tiers: the validator rejects an entry without them. Batches `batch-21` to `batch-60` are new: write both fields for every entry.
- Write exactly one file: `data/batches/{{BATCH}}.json`.
- Do not change any other file: not the word list, not other batches, not the tools.

## Steps

1. Print your words: `python3 tools/dictionary/batch_words.py {{BATCH}}`. Each line is `rank<TAB>headword<TAB>tier`.
2. Quiz tier only: also print ranks 1–2000 (`batch_words.py batch-01` to `batch_words.py batch-04`). You need them for `synonym_group`.
3. Write the entries in chunks of about 100, in rank order. After each chunk run
   `python3 tools/dictionary/validate.py data/batches/{{BATCH}}.json --allow-partial` and fix every error.
4. When all 500 entries are in, run `python3 tools/dictionary/validate.py data/batches/{{BATCH}}.json`.
   It must print `OK: 500 entries in 1 batch`. Fix and re-run until it does.
5. Report (see the last section).

## File format

The JSON Schema is `tools/dictionary/batch.schema.json`. The validator checks more rules than the schema.

```json
{
  "batch": "batch-01",
  "entries": [
    {
      "rank": 244,
      "headword": "large",
      "tier": "quiz",
      "pos": "adjective",
      "translations": ["большой", "крупный"],
      "ipa": "/lɑːdʒ/",
      "example": "They live in a large house near the river.",
      "example_ru": "Они живут в большом доме у реки.",
      "synonym_group": "big"
    }
  ]
}
```

A lookup-tier entry has the same fields except `synonym_group`:

```json
{
  "rank": 2001,
  "headword": "gender",
  "tier": "lookup",
  "pos": "noun",
  "translations": ["пол", "род"],
  "ipa": "/ˈdʒendə/",
  "example": "Please write your name and gender on the form.",
  "example_ru": "Пожалуйста, укажите в анкете своё имя и пол."
}
```

One entry per rank, sorted by rank, no gaps. Use UTF-8 and write Cyrillic and IPA characters as they are (no `\u` escapes needed).

## Field rules

**rank, headword** — copy them exactly from `batch_words.py` (case too: `Monday`, `English`, `TV`).

**tier** — `"quiz"` for ranks up to 2000, `"lookup"` above.

**pos** — the part of speech of the most frequent everyday meaning. One of:
`noun`, `verb`, `adjective`, `adverb`, `pronoun`, `preposition`, `conjunction`, `determiner`, `numeral`, `interjection`, `other`.
Use `determiner` for words like `this`, `every`, `some` before a noun, `numeral` for `two`, `hundred`, and `other` only when nothing else fits.

**translations** — Russian equivalents of that main meaning.
- The first translation is the answer the quiz shows as correct. It must be the single best everyday equivalent.
- Further translations are other common equivalents of the same meaning and part of speech. Do not add rare or unrelated meanings.
- Quiz tier: 1 to 3 translations. Lookup tier: 1 to 5.
- Dictionary form: nouns in nominative singular, adjectives in masculine nominative singular, verbs in the infinitive (imperfective first: `делать`, not `сделать`).
- Only Cyrillic letters, with single spaces or hyphens between words (`в течение`, `что-нибудь`). No Latin letters, digits, brackets, commas, slashes, notes or explanations. At most 40 characters. No duplicates.
- Lowercase, except words that Russian capitalizes (`Рождество`).

**ipa** — British (RP) broad transcription of the citation form, between slashes, like the design: `/ɔːlˈðəʊ/`, `/rɪˈlʌktənt/`, `/səˈdʒest/`.
- Allowed symbols only: vowels `a e i u æ ɑ ɒ ɔ ə ɜ ɛ ɪ ʊ ʌ`, consonants `b d f g ɡ h j k l m n ŋ p r s t v w x z θ ð ʃ ʒ ʔ`, marks `ː ˈ ˌ .`
- Write affricates as two symbols (`tʃ`, `dʒ`) and diphthongs as two vowels (`eɪ`, `aɪ`, `əʊ`, `aʊ`, `ɔɪ`, `ɪə`, `eə`, `ʊə`).
- Put `ˈ` before the stressed syllable of words with two or more syllables (one `ˈ` only); `ˌ` marks secondary stress. `ː` follows a vowel.
- Use the strong form of function words (`/ænd/`, `/fɔː/`, `/æt/`).
- No American symbols (`ɚ`, `ɝ`, `ɹ`, `ɾ`, `oʊ`), no spaces, no brackets, no optional sounds.

**example** (required, both tiers) — one natural English sentence that shows the meaning of the first translation.
- 4 to 14 words, simple everyday vocabulary (A2–B1), 10 to 140 characters.
- It must contain the headword or a regular form that starts with it: some word in the sentence must start with the headword (`house` → `houses`), or with the headword without a final `e`/`y` when the headword has four or more letters (`make` → `making`, `try` → `tried`). An irregular form does not count (`went` for `go`), so use the headword itself then.
- Capital letter first, `.` `!` or `?` last. Plain ASCII letters, digits, spaces and the punctuation `, . ; : ! ? ' " ( ) -`.
- No real people, brands, politics, violence or sex.

**example_ru** (required, both tiers) — a natural Russian translation of `example`, as a Russian speaker would say it.
- Translate the whole sentence. Use the first translation's meaning for the headword; the Russian word may be a form of it (`большом` for `большой`).
- 1 to 180 characters, one sentence. Capital letter first, `.` `!` or `?` last (a closing `»` or `"` may follow).
- Only Cyrillic letters, digits, spaces and the punctuation `, . ; : ! ? " ( ) « » - – —`. No Latin letters: write names and places in Cyrillic, and an English word in the translation would show the answer on the card.

**synonym_group** (quiz tier only) — prevents two correct answers in one quiz.
- Look at the quiz-tier words of ranks 1–2000. If a word with a *lower* rank has the same main meaning, so that a learner could fairly pick either as the answer (`large` → `big`, `begin` → `start`, `kid` → `child`), write that word's headword.
- Always use the lowest-ranked word of the group. That word's own `synonym_group` is its own headword. Never point at a word with a higher rank, and never chain: if `large` → `big`, then `huge` → `big`, not `large`.
- If no lower-ranked word has the same meaning, write the entry's own headword.
- Be conservative: only true near-synonyms. Related words (`hot` / `warm`, `buy` / `sell`) are not a group.

## Report

When the validator prints `OK: 500 entries in 1 batch`, reply in at most 10 lines:
- the batch id and the validator's OK line;
- headwords that look like a proper name, an abbreviation, a fragment or a non-English word (the lead may add them to `data/wordlist/exclusions.txt`); you must still write an entry for them;
- ranks where you are unsure of the translation or the part of speech.
