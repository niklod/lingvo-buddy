#if DEBUG
import Foundation
import LingvoCore
import SwiftUI

/// The tray menu with the design's sample numbers (`design/screenshots/tray_menu.png`).
@MainActor
enum TrayMenuSnapshots {
    /// A fixed moment, so "Next in 7 min" and the pause time never change between runs.
    private static let now = Date(timeIntervalSince1970: 1_792_000_000)

    static let designStats = TutorStats(
        streakDays: 6,
        todayAnswers: 24,
        todayCorrect: 21,
        accuracy: 0.87,
        reviewsLeftToday: 5,
        tierProgress: TierProgress(tier: .top1000, learned: 214, total: 1000),
        learningCount: 38,
        myWordsCount: 12
    )

    static var states: [SnapshotState] {
        [
            state("tray_menu", pausedUntil: nil, highlighted: .showWordNow),
            state("tray_menu_paused", pausedUntil: now.addingTimeInterval(60 * 60), highlighted: nil),
        ]
    }

    private static func state(_ name: String, pausedUntil: Date?, highlighted: TrayRow?) -> SnapshotState {
        let tray = TrayMenuState(
            stats: designStats,
            schedule: TrayScheduleInfo(
                nextCardAt: now.addingTimeInterval(7 * 60),
                interval: CardScheduleSettings.defaultInterval,
                pausedUntil: pausedUntil,
                hold: nil
            ),
            now: now
        )
        // The inline TextField is AppKit-backed: ImageRenderer would draw a placeholder.
        return SnapshotState(name: name, usesWindow: true, isPanel: true) {
            AnyView(
                TrayMenuView(state: tray, highlighted: highlighted) { TrayAddWordField { _ in } }
                    .background(Theme.Palette.desktop)
            )
        }
    }
}
#endif
