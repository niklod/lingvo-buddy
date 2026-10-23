/// Which builds may check the feed. Only a tagged Release (`X.Y.Z`) updates itself: a local or CI
/// dev build (`0.0.0-dev.N`) replaced by the latest Release would lose the developer's build.
public enum UpdaterGate {
    private static let releaseVersionParts = 3

    public static func allows(shortVersion: String) -> Bool {
        let parts = shortVersion.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == releaseVersionParts
            && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
