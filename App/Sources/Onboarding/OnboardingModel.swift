import Foundation
import LingvoCore
import Observation

/// What onboarding needs from the core. `Tutor` in the app; a stub in snapshots.
protocol OnboardingStoring: Sendable {
    func levelCheckSample(size: Int) throws -> LevelCheckSample
    func applyLevelCheck(_ answers: [LevelCheckAnswer]) throws -> LevelCheckOutcome
    func completeOnboarding() throws
}

extension Tutor: OnboardingStoring {}

enum OnboardingStep: Equatable {
    case welcome
    case levelIntro
    case levelWord(index: Int)
    case levelDone(LevelCheckOutcome)
    case setup

    /// "Step n of 3": welcome, level check, setup.
    var number: Int {
        switch self {
        case .welcome: 1
        case .levelIntro, .levelWord, .levelDone: 2
        case .setup: 3
        }
    }

    static let count = 3
}

/// The onboarding flow: welcome with the interval, the skippable level check,
/// then Focus and launch at login. Settings changes go through `SettingsModel`.
@MainActor
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep
    private(set) var sample: LevelCheckSample?
    private(set) var answers: [LevelCheckAnswer] = []
    @ObservationIgnored private let store: any OnboardingStoring
    @ObservationIgnored private let errors: ErrorPresenter?
    @ObservationIgnored var onFinish: (() -> Void)?

    /// `step` and `sample` other than the defaults are for snapshots.
    init(
        store: any OnboardingStoring,
        errors: ErrorPresenter?,
        step: OnboardingStep = .welcome,
        sample: LevelCheckSample? = nil
    ) {
        self.store = store
        self.errors = errors
        self.step = step
        self.sample = sample
    }

    var currentWord: DictionaryEntry? {
        guard case .levelWord(let index) = step, let words = sample?.words, words.indices.contains(index) else {
            return nil
        }
        return words[index]
    }

    /// The sample is drawn here, so the intro can name the tier and the word count.
    func showLevelIntro() {
        do {
            let sample = try store.levelCheckSample(size: LevelCheckSample.defaultSize)
            guard !sample.words.isEmpty else {
                step = .setup
                return
            }
            self.sample = sample
            step = .levelIntro
        } catch {
            // Without a sample the check cannot run; the rest of onboarding still can.
            errors?.show(error)
            step = .setup
        }
    }

    func startLevelCheck() {
        guard sample?.words.isEmpty == false else { return }
        answers = []
        step = .levelWord(index: 0)
    }

    func answer(knows: Bool) {
        guard let word = currentWord, case .levelWord(let index) = step else { return }
        answers += [LevelCheckAnswer(headword: word.headword, knows: knows)]
        if index + 1 < (sample?.words.count ?? 0) {
            step = .levelWord(index: index + 1)
        } else {
            finishLevelCheck()
        }
    }

    /// "Finish now": the answers so far still count.
    func finishLevelCheck() {
        do {
            step = .levelDone(try store.applyLevelCheck(answers))
            UserDataChanges.post(staleCards: .all)
        } catch {
            errors?.show(error)
        }
    }

    func skipLevelCheck() {
        step = .setup
    }

    func showSetup() {
        step = .setup
    }

    /// Finishing, skipping and closing the window all end onboarding for good.
    func finish() {
        do {
            try store.completeOnboarding()
        } catch {
            errors?.show(error)
        }
        onFinish?()
    }
}

/// A fixed sample and no writes: snapshots must not touch the learner's database.
final class SampleOnboardingStore: OnboardingStoring {
    private let sample: LevelCheckSample
    private let outcome: LevelCheckOutcome

    init(sample: LevelCheckSample, outcome: LevelCheckOutcome) {
        self.sample = sample
        self.outcome = outcome
    }

    func levelCheckSample(size: Int) throws -> LevelCheckSample { sample }
    func applyLevelCheck(_ answers: [LevelCheckAnswer]) throws -> LevelCheckOutcome { outcome }
    func completeOnboarding() throws {}
}
