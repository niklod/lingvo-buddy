import AppKit
import LingvoCore
import OSLog
import UniformTypeIdentifiers

/// The core side of CSV export / import. `Tutor` in the app.
protocol CSVTransferring: Sendable {
    func exportCSV() throws -> Data
    func importCSV(_ data: Data) throws -> CSVImportSummary
}

extension Tutor: CSVTransferring {}

/// What the Settings "Data" buttons call; `.none` in snapshots.
struct CSVTransferActions {
    let export: () -> Void
    let importFile: () -> Void

    static var none: CSVTransferActions { CSVTransferActions(export: {}, importFile: {}) }
}

/// Runs the save and open panels for CSV export / import. The panels are
/// Powerbox panels: the sandbox grants access to the chosen file only, which
/// the `files.user-selected.read-write` entitlement allows.
@MainActor
final class CSVTransferController {
    private let store: any CSVTransferring
    private let errors: ErrorPresenter
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "csv")

    init(store: any CSVTransferring, errors: ErrorPresenter) {
        self.store = store
        self.errors = errors
    }

    var actions: CSVTransferActions {
        CSVTransferActions(
            export: { [weak self] in self?.export() },
            importFile: { [weak self] in self?.importFile() }
        )
    }

    func export() {
        let data: Data
        do {
            data = try store.exportCSV()
        } catch {
            errors.show(error, title: String(localized: "Cannot export"))
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = Self.exportFileName(on: Date())
        panel.message = String(localized: "My words and the progress of every word.")
        present(panel) { [weak self] url in
            self?.write(data, to: url)
        }
    }

    func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Words in the file replace what LingvoBuddy has for them. Other words stay.")
        panel.prompt = String(localized: "Import")
        present(panel) { [weak self] url in
            self?.importContents(of: url)
        }
    }

    /// The local date: the ISO style defaults to UTC, which names a file
    /// saved just after midnight in Moscow with the day before.
    static func exportFileName(on date: Date) -> String {
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        return "LingvoBuddy \(day).csv"
    }

    /// A sheet on Settings when it is key, so the panel cannot open behind other apps.
    private func present(_ panel: NSSavePanel, onChoice: @escaping (URL) -> Void) {
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            onChoice(url)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            NSApp.activate()
            panel.begin(completionHandler: handler)
        }
    }

    private func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
            logger.notice("exported \(data.count) bytes")
        } catch {
            errors.show(error, title: String(localized: "Cannot export"))
        }
    }

    private func importContents(of url: URL) {
        do {
            let summary = try store.importCSV(try Self.readLimited(url))
            logger.notice("imported \(summary.words) words, \(summary.myWords) my words")
            UserDataChanges.post(staleCards: .all)
            errors.inform(Self.message(for: summary))
        } catch {
            errors.show(error, title: String(localized: "Cannot import this file"))
        }
    }

    /// Reads one byte past the limit, so the core can reject a huge file
    /// without the app loading all of it.
    private static func readLimited(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: Tutor.maxCSVImportBytes + 1) ?? Data()
    }

    private static func message(for summary: CSVImportSummary) -> String {
        if summary.words == 0 {
            return String(localized: "The file has no words. Nothing changed.")
        }
        let words = summary.words == 1
            ? String(localized: "Imported 1 word.")
            : String(localized: "Imported \(summary.words) words.")
        return words + " " + String(localized: "In My words: \(summary.myWords).")
    }
}
