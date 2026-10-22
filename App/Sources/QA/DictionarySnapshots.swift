#if DEBUG
import LingvoCore
import SwiftUI

/// The Dictionary window (`design/screenshots/dictionary_window.png`) over the
/// design sample state: the bundled dictionary, an in-memory user database
/// seeded with `DesignDemoSeed`, so the real list rules build the rows.
@MainActor
enum DictionarySnapshots {
    static var states: [SnapshotState] {
        [
            state("dictionary_window", list: .learning, search: ""),
            state("dictionary_window_search", list: .learning, search: "пред"),
            state("dictionary_window_queue", list: .queue, search: ""),
        ]
    }

    private static func state(_ name: String, list: WordList, search: String) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            do {
                let model = DictionaryModel(store: try seededTutor(), errors: nil)
                model.list = list
                model.search = search
                // A snapshot cannot wait for the typing pause of the search field.
                model.reload()
                return AnyView(WindowChrome {
                    DictionaryView(model: model, settings: SettingsModel(store: InMemorySettingsStore(), errors: nil))
                })
            } catch {
                return AnyView(Text("Snapshot setup failed: \(error.localizedDescription)").padding())
            }
        }
    }

    private static func seededTutor() throws -> Tutor {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "sqlite") else {
            throw AppEnvironment.SetupError.missingBundledDictionary
        }
        let dictionary = try DictionaryStore.open(at: url)
        let userDatabase = try UserDatabase.inMemory()
        try DesignDemoSeed.apply(to: userDatabase, dictionary: dictionary, now: SystemClock().now())
        return try Tutor(dictionary: dictionary, userDatabase: userDatabase)
    }
}

/// The window frame macOS draws around the real window: rounded corners,
/// hairline border, shadow and the three window buttons.
private struct WindowChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: DictionaryLayout.windowSize.width, height: DictionaryLayout.windowSize.height)
            .overlay(alignment: .topLeading) { trafficLights }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tray))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tray).strokeBorder(Theme.Palette.hairline))
            .shadow(color: Theme.Palette.shadow, radius: Theme.CardShadow.radius, y: Theme.CardShadow.offsetY)
            .padding(30)
            .background(Theme.Palette.desktop)
    }

    private var trafficLights: some View {
        HStack(spacing: 8) {
            ForEach(Theme.Palette.trafficLights, id: \.self) { color in
                Circle().fill(color).frame(width: 12, height: 12)
            }
        }
        .frame(height: DictionaryLayout.headerHeight)
        .padding(.leading, 16)
    }
}
#endif
