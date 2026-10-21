import AppKit
import SwiftUI

/// The "Launch at login" toggle, shared by Settings and onboarding. The state
/// is read again on appear and on activation: the learner can change the
/// login item in System Settings at any moment.
struct LaunchAtLoginRow: View {
    let launchAtLogin: any LaunchAtLoginControlling
    let errors: ErrorPresenter?
    /// Onboarding explains the option while it is off; Settings does not need to.
    let hintWhenOff: String?
    /// Starts with the real state, so the first layout already has the right height.
    @State private var state: LaunchAtLoginState

    init(launchAtLogin: any LaunchAtLoginControlling, errors: ErrorPresenter?, hintWhenOff: String? = nil) {
        self.launchAtLogin = launchAtLogin
        self.errors = errors
        self.hintWhenOff = hintWhenOff
        _state = State(initialValue: launchAtLogin.state)
    }

    var body: some View {
        SettingsRow(label: String(localized: "Launch at login"), hint: hint) {
            HStack(spacing: 8) {
                if state == .needsApproval {
                    Button(String(localized: "Open Login Items…")) { launchAtLogin.openSystemSettings() }
                        .controlSize(.small)
                }
                Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }
        .onAppear { state = launchAtLogin.state }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state = launchAtLogin.state
        }
    }

    private var hint: String? {
        switch state {
        case .needsApproval: String(localized: "Allow LingvoBuddy in System Settings > General > Login Items.")
        case .off: hintWhenOff
        case .on: nil
        }
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { state != .off },
            set: { enabled in
                do {
                    try launchAtLogin.setEnabled(enabled)
                } catch {
                    errors?.show(error)
                }
                state = launchAtLogin.state
            }
        )
    }
}
