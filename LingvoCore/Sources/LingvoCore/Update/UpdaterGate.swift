/// Which builds may check the feed. Only a tagged Release (`X.Y.Z`) updates itself: a local or CI
/// dev build (`0.0.0-dev.N`) replaced by the latest Release would lose the developer's build.
public enum UpdaterGate {
    private static let releaseVersionParts = 3

    public static func allows(shortVersion: String) -> Bool {
        let parts = shortVersion.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == releaseVersionParts && parts.allSatisfy(isReleaseNumber)
    }

    // The release workflow accepts the same shape for a tag: plain ASCII digits, no leading zero.
    private static func isReleaseNumber(_ part: Substring) -> Bool {
        guard let first = part.first, part.allSatisfy(\.isASCIIDigit) else { return false }
        return part.count == 1 || first != "0"
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
