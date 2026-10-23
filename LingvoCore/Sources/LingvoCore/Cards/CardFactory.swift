import Foundation

/// Turns a picked word into a ready card: direction, prompt and shuffled options.
struct CardFactory {
    let directions: DirectionChooser
    let distractors: DistractorPicker
    let random: any RandomSource

    func card(for picked: PickedWord, at now: Date) throws -> Card {
        let entry = picked.entry
        let direction = directions.direction(for: picked.progress)
        guard let translation = entry.primaryRussian,
              let answer = DistractorPicker.optionText(of: entry, direction: direction) else {
            throw LingvoCoreError.invalidDictionary("\(entry.headword) has no Russian translation")
        }
        let options = random.shuffled([answer] + (try distractors.distractors(for: entry, direction: direction)))
        return Card(
            headword: entry.headword,
            prompt: direction == .enToRu ? entry.headword : translation,
            direction: direction,
            kind: picked.kind,
            source: picked.isMine ? .mine : .rank(entry.rank),
            ipa: entry.ipa,
            partOfSpeech: entry.partOfSpeech,
            options: options,
            correctIndex: options.firstIndex(of: answer) ?? 0,
            example: entry.example,
            mastery: picked.progress?.mastery ?? 0,
            russianExample: entry.russianExample,
            isPractice: picked.progress?.isTooSoon(at: now) ?? false
        )
    }
}
