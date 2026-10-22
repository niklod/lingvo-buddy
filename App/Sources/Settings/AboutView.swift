import AppKit
import SwiftUI

/// What the About tab shows. The attribution comes from the bundled
/// dictionary's `meta` table, so it always matches the data that ships.
struct AboutInfo: Equatable {
    let version: String
    let build: String
    /// `meta.license`: the wordfreq CC BY-SA 4.0 credit.
    let attribution: String?
    /// `meta.source`: which word list the dictionary was built from.
    let source: String?

    static func current(dictionaryMeta: [String: String], bundle: Bundle = .main) -> AboutInfo {
        AboutInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            attribution: dictionaryMeta["license"],
            source: dictionaryMeta["source"]
        )
    }
}

struct AboutView: View {
    let info: AboutInfo

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            VStack(spacing: 6) {
                // The app icon: Kapa the capybara in her onsen (AppIcon in Assets.xcassets).
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)
                Text("LingvoBuddy")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(String(localized: "Version \(info.version) (\(info.build))"))
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(String(localized: "English words in your menu bar, a few minutes at a time."))
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Theme.Palette.textBody)
                    .padding(.top, 4)
            }
            SettingsSection(title: String(localized: "Word data")) {
                Text(info.attribution ?? String(localized: "The dictionary has no attribution record."))
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = info.source {
                    Text(String(localized: "Source: \(source)"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(String(localized: "All your progress stays on this Mac."))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
