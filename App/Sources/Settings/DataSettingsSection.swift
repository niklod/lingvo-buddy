import SwiftUI

/// Backup and move to a new Mac: my words and progress as a CSV file.
struct DataSettingsSection: View {
    let transfer: CSVTransferActions

    var body: some View {
        SettingsSection(title: String(localized: "Data")) {
            SettingsRow(
                label: String(localized: "My words and progress"),
                hint: String(localized: "A CSV file for a backup or a new Mac. The streak and accuracy history stay here.")
            ) {
                HStack(spacing: 8) {
                    Button(String(localized: "Export to CSV…"), action: transfer.export)
                    Button(String(localized: "Import from CSV…"), action: transfer.importFile)
                }
                .controlSize(.small)
            }
        }
    }
}
