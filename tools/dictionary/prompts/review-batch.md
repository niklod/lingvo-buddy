# Review one quiz-tier dictionary batch

You are the second agent on a quiz-tier batch (`batch-01` to `batch-04`) of the LingvoBuddy dictionary.
Replace `{{BATCH}}` with the batch id you were given. Run all commands from the repository root.
The generation rules are in `tools/dictionary/prompts/generate-batch.md`. Read them first: they are the standard you review against.

## What to check in every entry of `data/batches/{{BATCH}}.json`

1. **Meaning.** The first translation is the best everyday Russian equivalent of the headword's most frequent meaning. A wrong meaning is the main defect to find (for example `left` translated as `оставил` instead of `левый`, or a rare meaning first).
2. **Part of speech.** `pos` matches the meaning of the translations, and all translations have that part of speech.
3. **Translations.** At most 3, in dictionary form, no rare or unrelated meanings, no near-duplicates that add nothing.
4. **Example.** A natural sentence that uses the headword in the same meaning as the first translation.
   `example_ru` is a natural Russian translation of that sentence, in the same meaning, with no English words left in it.
5. **IPA.** A plausible British transcription of the headword, with the stress on the right syllable.
6. **synonym_group.** Points at the lowest-ranked quiz word with the same main meaning, or at the headword itself. Remove groups between words that are only related; add a group when two words would both be correct answers.

## How to fix

- Edit the entry in place. Do not add, remove or reorder entries, and do not change other files.
- After your edits run `python3 tools/dictionary/validate.py data/batches/{{BATCH}}.json`. It must print `OK: 500 entries in 1 batch`.
- If all quiz batches exist, also run `python3 tools/dictionary/validate.py --through 2000` to check synonym groups across them.

## Report

Reply in at most 15 lines: the validator's OK line, the number of entries you changed, and one line per change of meaning or part of speech (`rank headword: old → new`). Skip pure IPA, example or `example_ru` polish in the list; give only their count.
