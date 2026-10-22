/// Virtual key codes of the keys the panels answer to. Codes, not characters:
/// they stay the same on every keyboard layout.
enum KeyCode {
    static let escape: UInt16 = 53
    /// Return and keypad Enter.
    static let returnKeys: Set<UInt16> = [36, 76]
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}
