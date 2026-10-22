# LingvoBuddy

A macOS menu-bar app that teaches a Russian speaker the most frequent English words. Short quiz cards come on a timer, and learned words come back as spaced reviews.

## Language

### Dictionary

**Learner**:
The one person who uses the app.
_Avoid_: user, student

**Headword**:
The English dictionary form of a word, and the key of every word in the app.
_Avoid_: term, lemma

**Rank**:
The position of a headword in the frequency list; 1 is the most frequent word.

**Bundled dictionary**:
The read-only offline list of up to 30,000 ranked headwords with Russian translations, IPA and part of speech.
_Avoid_: word list (the export input it is built from), database

**Quiz entry**:
A dictionary entry with full card data: an example, its Russian example and a synonym group. Ranks 1–2000. Code: `DictionaryTier.quiz`.

**Lookup entry**:
A dictionary entry with an example and its Russian example but no synonym group, used only by quick add. Ranks 2001–30,000. Code: `DictionaryTier.lookup`.

**Tier**:
A frequency band that new words come from: Top‑1000 (ranks 1–1000), then Top‑2000 (ranks 1001–2000). Code: `TopTier`. Not the same as quiz entry and lookup entry.
_Avoid_: level

**Open tier**:
The tier new words come from now. Top‑2000 opens when every Top‑1000 card word is learned, and stays open once one of its words got an answer as a new word.

**Quiz exclusion**:
A headword of ranks 1001–2000 that never becomes a card or a distractor (a name, a fragment, slang, a vulgar word). It stays in the dictionary for lookup.
_Avoid_: blacklist, junk word

**Card word**:
A headword that can become a card: ranks 1–2000, minus the quiz exclusions. Code: `DictionaryStore.quizEntries`.

**Synonym group**:
Quiz entries whose main meanings a learner could fairly swap as answers. It is named by the headword of its lowest-ranked member, and its members are never distractors for each other. Code: `synonym_group`.

**My word**:
A word the learner added with quick add, with the learner's translation and optional example. It comes before new dictionary words. Code: `MyWord`, `CardKind.mine`, `CardSource.mine`.
_Avoid_: custom word, user word

### Cards

**Card**:
One quiz question about one word: a prompt, four options, one of them correct.
_Avoid_: flashcard, question

**Direction**:
The way a card translates: EN→RU (`enToRu`) or RU→EN (`ruToEn`). The direction setting adds Mix, about 70% EN→RU.

**Kind**:
Why a card shows its word: new (a dictionary word not yet learned), review (a learned word that is due), or mine (a my word not yet learned). Code: `CardKind`; the badge shows "New", "Review" or "My word".

**Distractor**:
One of the three wrong options of a card: same part of speech, nearby rank, not in the correct word's synonym group and no shared translation.
_Avoid_: wrong answer (that is the learner's pick)

**Don't know**:
The card button that shows the answer. It counts as a wrong answer. Code: `AnswerOutcome.dontKnow`.

**Example**:
The English sentence a card shows after the answer. For a my word it is the "Where I saw it" text, or the dictionary example when that field is empty.

**Russian example**:
The dictionary's Russian translation of its example, shown under the example after the answer. A my word with its own "Where I saw it" text has none. Code: `russianExample`; `example_ru` in the dictionary data.

### Learning

**Mastery**:
The count, 0 to 4, of counted correct answers in a row for a word. Code: `mastery`.
_Avoid_: score, level

**Mastery dot**:
One of the four dots that show mastery on a card or a Dictionary row.
_Avoid_: dot (alone; see waiting dot)

**Counted correct answer**:
A correct answer given at least one hour after the previous counted one. Only these add a mastery dot.

**Queued**:
The state of a card word of the open tier that has no answer yet. The Dictionary window lists these words as the queue.

**Learning**:
The state of a word that has answers but is not learned. Code: `WordStatus.learning`.

**Learned**:
The state of a word that reached mastery 4 with at least one correct answer in each direction. It comes back only as reviews. Code: `WordStatus.learned`.
_Avoid_: known, mastered

**Review**:
A card for a learned word whose due date has come. A wrong answer sends the word back to learning with mastery 0.

**Review stage**:
The step of a learned word's review schedule: 1, 2, 3 for reviews 7, 21 and 60 days later; after that every 60 days. Code: `review_stage` (0 while learning).

**Review cap**:
The limit on the share of cards that are reviews (default 20%). A review comes only if none came in the last ⌈1/share⌉−1 answers. Code: `reviewShare`, `reviewCapWindow`.
_Avoid_: review quota

**Active words**:
The words in learning. New dictionary words enter only while there are fewer than the max active new words (default 10). Code: `maxActiveNewWords`.

**Level check**:
The onboarding test of about 30 words across the open tier, answered "Know" or "Don't know". Known words, and queued words below the learner's level, become learned without logged answers. Code: `LevelCheck`.
_Avoid_: placement test

### Schedule

**Timed card**:
A card the interval timer brings. Quiet rules apply to it. Code: `CardContext.Trigger.timer`.

**On-demand card**:
A card the learner asks for ("Show word now", ⌥⌘W). It ignores every quiet rule. Code: `CardContext.Trigger.onDemand`.

**Interval**:
The time between timed cards: 5–120 minutes, default 15. The next countdown starts when the card closes.

**Later**:
The card button that puts the card aside: the same card comes back first after 5 minutes. No stats change. Code: `Tutor.later`.
_Avoid_: snooze, postpone

**Skip**:
Closing a card with "×" or Esc. The word is left out of the next card only, with no penalty. Code: `Tutor.skip`.
_Avoid_: dismiss

**Deferral**:
The in-memory record of later and skipped cards; an app restart forgets it. Code: `CardDeferrals`.

**Auto-close**:
An untouched timed card closes itself after 30 seconds, with no stats change.

**Engaged**:
The state of a card the learner gave focus to or answered. An engaged card does not auto-close.

**Waiting card**:
A card that auto-closed and waits for the learner. A click on the menu-bar icon reopens it. Code: `CardSchedule.waitingCard`.

**Waiting dot**:
The dot on the menu-bar icon while a waiting card exists.
_Avoid_: badge, dot (alone)

**Quiet rule**:
A condition that holds timed cards back: a pause, quiet hours, Focus, or a full-screen app. Code: `NoCardReason`.

**Quiet hours**:
A daily local time range with no timed cards; default 23:00–09:00.
_Avoid_: night mode, do not disturb

**Pause**:
The learner's choice to stop timed cards for 1 hour, 3 hours, or until midnight. Code: `PauseOption`, `pausedUntil`.

**Hold**:
A quiet rule other than a pause (quiet hours, Focus, full screen) while it keeps the timer retrying every minute. The tray shows the hold instead of a countdown. Code: `ScheduleHold`.

### App

**Menu-bar icon**:
The "Aa" status item. A click reopens a waiting card, or else opens the tray.
_Avoid_: tray icon

**Tray**:
The panel under the menu-bar icon with the streak, progress, today's stats, pause, interval, the add-word field and the app menu items. Code: `TrayMenu*`, `TrayPanel`.
_Avoid_: popover, dropdown

**Quick add**:
The panel that adds a my word: ⌥⌘L, the Services item "Add to LingvoBuddy", the tray field, or "+ Word" in the Dictionary window. Code: `QuickAdd*`.

**Example preview**:
The read-only dictionary example, with its Russian example, that quick add shows under "Where I saw it" while that field is empty. Code: `QuickAddPreview.example`, `QuickAddPreview.russianExample`, `ExamplePreview`.

**Dictionary window**:
The window that lists the learner's words: Learning, Learned, My words and the queue. Code: `WordList`.

**Streak**:
The number of consecutive local days with at least one answer, ending today, or yesterday while today has no answer yet.

**Accuracy**:
The share of correct answers over the last 7 days, with "Don't know" counted as wrong.

**Tier progress**:
Learned card words of the open tier out of all its card words ("learned / 1000"). Code: `TierProgress`.
