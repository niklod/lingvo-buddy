import Foundation

/// The Focus step of onboarding: whether LingvoBuddy may read the Focus state.
enum FocusAccess: Equatable {
    /// The build has no Communication Notifications entitlement, so macOS never
    /// asks. An ad-hoc signed build is always in this state.
    case unavailable
    case notAsked
    case allowed
    case denied
}

@MainActor
protocol FocusAccessRequesting: AnyObject {
    var access: FocusAccess { get }
    /// Shows the system prompt when the learner was not asked yet; otherwise
    /// answers at once with the current state.
    func requestAccess(_ answered: @escaping @MainActor (FocusAccess) -> Void)
}

/// A fixed state for snapshots: never shows the system prompt.
@MainActor
final class FixedFocusAccess: FocusAccessRequesting {
    private(set) var access: FocusAccess

    init(_ access: FocusAccess) {
        self.access = access
    }

    func requestAccess(_ answered: @escaping @MainActor (FocusAccess) -> Void) {
        answered(access)
    }
}
