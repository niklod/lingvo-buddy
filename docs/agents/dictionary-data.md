# Dictionary data

The bundled dictionary is built from `data/batches/batch-NN.json` (60 batches of 500 ranks for the 30,000 ranks of the word list; batches 21–60 do not exist yet) by `tools/dictionary/` (Python standard library only, 3.9+). `make test` runs the tool tests, `validate.py --full`, the build and `lingvo-dict check`. `--full` requires every rank up to the end of the last batch file, so a missing batch in the middle fails, and it names the batches after the last file that are not generated yet. The field rules live in `tools/dictionary/prompts/generate-batch.md`: that prompt is the single source for what a good entry is.

## The contract has two sides

The SQLite schema exists twice: `tools/dictionary/lingvo_dict/build.py` writes the file and `LingvoCore/Sources/LingvoCore/Dictionary/DictionarySchema.swift` builds the in-memory test dictionary. Change both in the same commit, and raise `SCHEMA_VERSION` / `schemaVersion` together. `lingvo-dict check` (in `make test`, through `DictionaryStore+Contract.swift`) fails when they drift apart.

A contract change also touches:
- `tools/dictionary/lingvo_dict/contract.py` (fields, POS values, ranks), then `python3 tools/dictionary/write_schema.py` to regenerate `batch.schema.json`;
- `PartOfSpeech` / `DictionaryTier` in `LingvoCore/Sources/LingvoCore/Dictionary/DictionaryEntry.swift`;
- `DictionaryStore.swift`, which rejects a file built for an older contract with a clear message;
- the core test fixture `LingvoCore/Tests/LingvoCoreTests/Fixtures/sample-dictionary.json`.

## Ranks are fixed

Every batch entry is tied to its rank in `data/wordlist/wordlist.tsv`. The export ranks the lemmas of the top 60,000 `wordfreq` forms first (ranks 1–24,494), then appends new lemmas of the top 100,000 forms up to rank 30,000; one pass over all forms would move ranks from 180 on. A new run of `export_wordlist.py` with changed rule files shifts ranks and breaks every batch after the change, so leave the word list as it is. A bad headword goes on one of two lists:

- `data/quiz-exclusions.txt`: ranks 1001–2000 only. The word stays in the dictionary for quick-add lookup but never becomes a card or a distractor. Use it for names, clippings, inflected forms, slang and vulgar main senses. Such an entry still needs its example and synonym group, in the lookup sense.
- `data/wordlist/exclusions.txt`: drops the word from the word list itself. It takes effect only on a new export, so use it only for ranks that no batch file covers yet, and check after the export that every line up to the end of the last batch is byte-identical. A listed word also drops that bare form from its lemma: "cm" would take frequency from "centimeter" and move ranks, so list the source form ("cms") instead.

## Synonym groups

The key of a group is the headword of its lowest-ranked member in ranks 1–2000. A word with no near-synonym uses its own headword. This rule lets parallel agents that work on different rank ranges pick the same key without talking.

- `validate.py` rejects chains (the error names the final key), loops, keys of a higher rank, keys that are not quiz-tier headwords, and keys with no entry in a complete loaded batch.
- It does not fail on this convention, which the data keeps: words with the same first translation share one group. After any group edit, run `python3 tools/dictionary/validate.py --full --report-shared-translations`. The first list ("same first translation, different groups") must be empty. The second list ("one group, different first translations") is for review: most of it is real synonyms (`big` большой / `huge` огромный); look for wrong merges. Quiz exclusions are left out.
- Generators miss real near-synonyms more often than they invent false ones. Before you merge new groups, test known pairs (`big`/`large`, `begin`/`start`, `kid`/`child`, `shop`/`store`) and look at every shared group that gained a member.

## Workflow: generate, review, validate, build

1. **Generate.** One sub-agent per batch, with `tools/dictionary/prompts/generate-batch.md` and `{{BATCH}}` replaced. It validates its own file until `OK: 500 entries in 1 batch`.
2. **Review.** Quiz-tier batches (`batch-01` to `batch-04`) get a second agent with `tools/dictionary/prompts/review-batch.md`. Wrong meaning of the first translation is the main defect.
3. **Validate.** `python3 tools/dictionary/validate.py --full` must pass.
4. **Build.** `make dictionary` writes `App/Resources/dictionary.sqlite` (gitignored); `make app` runs it. Then `make test`.

Collect the headwords that generators report as names, fragments or vulgar words, and decide on `data/quiz-exclusions.txt` before the batches merge.

## Adding a field to existing entries

When existing entries need a new or changed field (for example examples and synonym groups for ranks 1001–2000), do not let agents edit the batch files in parallel. Use patches:

1. Write a context TSV of ranks 1–2000 (rank, headword, pos, translations, synonym_group) so each agent sees the existing keys.
2. Give each sub-agent one range of about 250 ranks. It writes only a patch file outside the repo: `{"from": N, "to": M, "entries": [{"rank", "headword", <new fields>}]}`, one item per rank in order. It changes no other field, follows `generate-batch.md`, and self-checks: every rank once, headword equals the context file, every key has a rank at or below the entry's rank, no chains.
3. The lead merges the patches into the batch files with a script that keeps the file layout (one entry per line, keys in `QUIZ_FIELDS` order), runs the synonym-group checks above, then `validate.py --full` and `make test`.
