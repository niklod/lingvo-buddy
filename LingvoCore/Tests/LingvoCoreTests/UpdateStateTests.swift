import Foundation
import LingvoCore
import Testing

@Suite("Update state")
struct UpdateStateTests {
    @Test("a check that finds a version shows the update")
    func idleToAvailable() {
        #expect(UpdateState.idle.applying(.foundVersion("0.3.0")) == .available(version: "0.3.0"))
    }

    @Test("a click starts the download at zero")
    func availableToDownloading() {
        let next = UpdateState.available(version: "0.3.0").applying(.installClicked)
        #expect(next == .downloading(version: "0.3.0", fraction: 0))
    }

    @Test("progress moves the fraction and clamps it to 0...1")
    func progress() {
        let state = UpdateState.downloading(version: "0.3.0", fraction: 0)
        #expect(state.applying(.progress(0.42)) == .downloading(version: "0.3.0", fraction: 0.42))
        #expect(state.applying(.progress(1.7)) == .downloading(version: "0.3.0", fraction: 1))
        #expect(state.applying(.progress(-1)) == .downloading(version: "0.3.0", fraction: 0))
    }

    @Test("a progress that is not a number counts as zero, and infinity as done")
    func progressNotANumber() {
        let state = UpdateState.downloading(version: "0.3.0", fraction: 0.5)
        #expect(state.applying(.progress(.nan)) == .downloading(version: "0.3.0", fraction: 0))
        #expect(state.applying(.progress(.infinity)) == .downloading(version: "0.3.0", fraction: 1))
        #expect(state.applying(.progress(-.infinity)) == .downloading(version: "0.3.0", fraction: 0))
    }

    @Test("progress outside a download changes nothing")
    func progressElsewhere() {
        #expect(UpdateState.idle.applying(.progress(0.5)) == .idle)
        #expect(UpdateState.available(version: "0.3.0").applying(.progress(0.5)) == .available(version: "0.3.0"))
    }

    @Test("a verified download restarts the app")
    func downloadingToRestarting() {
        let state = UpdateState.downloading(version: "0.3.0", fraction: 1)
        #expect(state.applying(.downloadVerified) == .restarting(version: "0.3.0"))
    }

    @Test("an error fails the update from any state that knows a version")
    func anyStateToFailed() {
        let reason = UpdateFailureReason.noConnection
        #expect(UpdateState.available(version: "0.3.0").applying(.failed(reason)) == .failed(version: "0.3.0", reason: reason))
        #expect(
            UpdateState.downloading(version: "0.3.0", fraction: 0.4).applying(.failed(reason))
                == .failed(version: "0.3.0", reason: reason)
        )
        #expect(
            UpdateState.restarting(version: "0.3.0").applying(.failed(.other))
                == .failed(version: "0.3.0", reason: .other)
        )
    }

    @Test("a new failure replaces the reason of the last one")
    func failedAgain() {
        let failed = UpdateState.failed(version: "0.3.0", reason: .noConnection)
        #expect(failed.applying(.failed(.verificationFailed)) == .failed(version: "0.3.0", reason: .verificationFailed))
    }

    @Test(
        "a verified download outside a download changes nothing",
        arguments: [
            UpdateState.idle, .available(version: "0.3.0"), .restarting(version: "0.3.0"),
            .failed(version: "0.3.0", reason: .other),
        ]
    )
    func verifiedElsewhere(state: UpdateState) {
        #expect(state.applying(.downloadVerified) == state)
    }

    @Test("an error with no update known leaves the state idle")
    func failedWhileIdle() {
        #expect(UpdateState.idle.applying(.failed(.noConnection)) == .idle)
    }

    @Test("a click in failed is Retry: the download starts again")
    func retry() {
        let state = UpdateState.failed(version: "0.3.0", reason: .noConnection)
        #expect(state.applying(.installClicked) == .downloading(version: "0.3.0", fraction: 0))
    }

    @Test("a click while downloading, restarting or idle changes nothing")
    func clicksIgnored() {
        let downloading = UpdateState.downloading(version: "0.3.0", fraction: 0.4)
        #expect(downloading.applying(.installClicked) == downloading)
        #expect(UpdateState.restarting(version: "0.3.0").applying(.installClicked) == .restarting(version: "0.3.0"))
        #expect(UpdateState.idle.applying(.installClicked) == .idle)
    }

    @Test("a check that finds nothing clears a failure and an offer")
    func foundNothing() {
        #expect(UpdateState.failed(version: "0.3.0", reason: .other).applying(.foundNothing) == .idle)
        #expect(UpdateState.available(version: "0.3.0").applying(.foundNothing) == .idle)
    }

    // Retry runs a new check: the download that follows installs what that check found.
    @Test("a version found during a download names the version that downloads")
    func foundDuringDownload() {
        let downloading = UpdateState.downloading(version: "0.3.0", fraction: 0.4)
        #expect(downloading.applying(.foundVersion("0.4.0")) == .downloading(version: "0.4.0", fraction: 0.4))
    }

    @Test("a check never interrupts a restart")
    func checksDuringRestart() {
        let restarting = UpdateState.restarting(version: "0.3.0")
        #expect(restarting.applying(.foundNothing) == restarting)
        #expect(restarting.applying(.foundVersion("0.4.0")) == restarting)
    }

    @Test("a Retry whose check finds no update anymore hides the button")
    func retryFindsNothing() {
        let retrying = UpdateState.failed(version: "0.3.0", reason: .other).applying(.installClicked)
        #expect(retrying.applying(.foundNothing) == .idle)
    }

    @Test("a newer check result replaces the offered version, and a failure keeps waiting")
    func foundVersionAgain() {
        #expect(UpdateState.available(version: "0.3.0").applying(.foundVersion("0.4.0")) == .available(version: "0.4.0"))
        #expect(
            UpdateState.failed(version: "0.3.0", reason: .other).applying(.foundVersion("0.3.0"))
                == .available(version: "0.3.0")
        )
    }
}

@Suite("Update state: values for the UI")
struct UpdateStateDerivedTests {
    @Test("idle shows no button")
    func idleButton() {
        #expect(UpdateState.idle.button == nil)
    }

    @Test(
        "each state shows its label and names the version the click installs",
        arguments: [
            (UpdateState.available(version: "0.3.0"), UpdateButton(label: .version, version: "0.3.0")),
            (.downloading(version: "0.3.0", fraction: 0.42), UpdateButton(label: .percent(42), version: "0.3.0")),
            (.downloading(version: "0.3.0", fraction: 0.996), UpdateButton(label: .percent(100), version: "0.3.0")),
            (.restarting(version: "0.3.0"), UpdateButton(label: .restarting, version: "0.3.0")),
            (.failed(version: "0.3.0", reason: .other), UpdateButton(label: .retry, version: "0.3.0")),
        ]
    )
    func button(state: UpdateState, expected: UpdateButton) {
        #expect(state.button == expected)
    }

    @Test("only the version and Retry accept clicks")
    func clickability() {
        #expect(UpdateButton(label: .version, version: "0.3.0").acceptsClicks)
        #expect(UpdateButton(label: .retry, version: "0.3.0").acceptsClicks)
        #expect(!UpdateButton(label: .percent(42), version: "0.3.0").acceptsClicks)
        #expect(!UpdateButton(label: .restarting, version: "0.3.0").acceptsClicks)
    }

    @Test("only failed has a failure line")
    func failureLine() {
        #expect(UpdateState.failed(version: "0.3.0", reason: .noConnection).failureReason == .noConnection)
        #expect(UpdateState.available(version: "0.3.0").failureReason == nil)
        #expect(UpdateState.idle.failureReason == nil)
    }

    @Test("the update mark shows in available and failed only")
    func updateMark() {
        #expect(UpdateState.available(version: "0.3.0").showsUpdateMark)
        #expect(UpdateState.failed(version: "0.3.0", reason: .other).showsUpdateMark)
        #expect(!UpdateState.idle.showsUpdateMark)
        #expect(!UpdateState.downloading(version: "0.3.0", fraction: 0.4).showsUpdateMark)
        #expect(!UpdateState.restarting(version: "0.3.0").showsUpdateMark)
    }
}

@Suite("Update failure reason")
struct UpdateFailureReasonTests {
    private func reason(domain: String, code: Int) -> UpdateFailureReason {
        UpdateFailureReason(error: NSError(domain: domain, code: code))
    }

    @Test(
        "offline-like URL errors mean no connection",
        arguments: [
            NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
            NSURLErrorCannotFindHost, NSURLErrorNetworkConnectionLost,
            // The server refuses or the route is down: the learner sees no difference from offline.
            NSURLErrorCannotConnectToHost,
        ]
    )
    func noConnection(code: Int) {
        #expect(reason(domain: NSURLErrorDomain, code: code) == .noConnection)
    }

    @Test("other URL errors are not blamed on the connection")
    func otherURLError() {
        #expect(reason(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse) == .other)
    }

    @Test("Sparkle signature and validation errors mean verification failed", arguments: [3001, 3002])
    func verification(code: Int) {
        #expect(reason(domain: "SUSparkleErrorDomain", code: code) == .verificationFailed)
    }

    @Test("everything else is other")
    func other() {
        #expect(reason(domain: "SUSparkleErrorDomain", code: 4000) == .other)
        #expect(reason(domain: "SomethingElse", code: 3001) == .other)
    }

    @Test("an underlying URL error counts")
    func underlying() {
        let inner = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let outer = NSError(domain: "SUSparkleErrorDomain", code: 2001, userInfo: [NSUnderlyingErrorKey: inner])
        #expect(UpdateFailureReason(error: outer) == .noConnection)
    }

    @Test("a Swift URLError counts as its NSError")
    func swiftURLError() {
        #expect(UpdateFailureReason(error: URLError(.notConnectedToInternet)) == .noConnection)
    }

    @Test("the cause may be any of several underlying errors")
    func secondOfMany() {
        let errors = [
            NSError(domain: "SomethingElse", code: 1),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut),
        ]
        let outer = NSError(domain: "SUSparkleErrorDomain", code: 4005, userInfo: [NSMultipleUnderlyingErrorsKey: errors])
        #expect(UpdateFailureReason(error: outer) == .noConnection)
    }

    // Offline, Sparkle can also fail to verify what it could not fetch: the network is the cause.
    @Test("an offline cause beats a signature cause")
    func offlineBeatsSignature() {
        let errors = [
            NSError(domain: "SUSparkleErrorDomain", code: 3002),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
        ]
        let outer = NSError(domain: "SUSparkleErrorDomain", code: 4005, userInfo: [NSMultipleUnderlyingErrorsKey: errors])
        #expect(UpdateFailureReason(error: outer) == .noConnection)
    }

    @Test("the search stops 6 levels deep", arguments: [(6, UpdateFailureReason.noConnection), (7, .other)])
    func depthLimit(levels: Int, expected: UpdateFailureReason) {
        var error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        for _ in 0..<levels {
            error = NSError(domain: "SUSparkleErrorDomain", code: 4005, userInfo: [NSUnderlyingErrorKey: error])
        }
        #expect(UpdateFailureReason(error: error) == expected)
    }

    // The shape Sparkle 2.10 reports for a dmg whose EdDSA signature does not match.
    @Test("a signature error deep inside an installation error means verification failed")
    func nestedVerification() {
        let mismatch = NSError(domain: "SUSparkleErrorDomain", code: 3002)
        let validation = NSError(
            domain: "SUSparkleErrorDomain", code: 4005,
            userInfo: [NSMultipleUnderlyingErrorsKey: [mismatch]]
        )
        let outer = NSError(domain: "SUSparkleErrorDomain", code: 4005, userInfo: [NSUnderlyingErrorKey: validation])
        #expect(UpdateFailureReason(error: outer) == .verificationFailed)
    }
}

@Suite("Updater gate")
struct UpdaterGateTests {
    @Test("a Release version X.Y.Z starts the updater", arguments: ["0.4.0", "1.2.3", "10.20.300"])
    func release(version: String) {
        #expect(UpdaterGate.allows(shortVersion: version))
    }

    @Test(
        "dev builds and malformed versions never start it",
        arguments: [
            "0.0.0-dev.12", "0.0.0-dev", "0.1", "1.2.3.4", "v1.2.3", "1.2.x", "1..3", " 1.2.3", "",
            "1.2.3 ", "1.2.3-beta", "1.2.", "١.٢.٣",
        ]
    )
    func notRelease(version: String) {
        #expect(!UpdaterGate.allows(shortVersion: version))
    }

    // CI tags are vX.Y.Z with plain numbers; "01.2.3" is no tag that CI makes.
    @Test("a part with a leading zero never starts it", arguments: ["01.2.3", "1.02.3", "1.2.03", "00.1.0"])
    func leadingZero(version: String) {
        #expect(!UpdaterGate.allows(shortVersion: version))
    }
}
