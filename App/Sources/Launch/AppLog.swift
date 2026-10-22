import OSLog

extension Logger {
    /// One subsystem for the whole app, so one `log stream` predicate shows every category.
    private static let appSubsystem = "com.niklod.LingvoBuddy"

    static func app(category: String) -> Logger {
        Logger(subsystem: appSubsystem, category: category)
    }
}
