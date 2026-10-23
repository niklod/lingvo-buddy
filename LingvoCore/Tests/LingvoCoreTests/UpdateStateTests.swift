import Foundation
import LingvoCore
import Testing

@Suite("Update state")
struct UpdateStateTests {
    @Test("a check that finds a version shows the update")
    func idleToAvailable() {
        #expect(UpdateState.idle.applying(.foundVersion("0.3.0")) == .available("0.3.0"))
    }

    @Test("a click starts the download at zero")
    func availableToDownloading() {
        let next = UpdateState.available("0.3.0").applying(.installClicked)
        #expect(next == .downloading(version: "0.3.0", fraction: 0))
    }

    @Test("progress moves the fraction and clamps it to 0...1")
    func progress() {
        let state = UpdateState.downloading(version: "0.3.0", fraction: 0)
        #expect(state.applying(.progress(0.42)) == .downloading(version: "0.3.0", fraction: 0.42))
        #expect(state.applying(.progress(1.7)) == .downloading(version: "0.3.0", fraction: 1))
        #expect(state.applying(.progress(-1)) == .downloading(version: "0.3.0", fraction: 0))
    }

    @Test("progress outside a download changes nothing")
    func progressElsewhere() {
        #expect(UpdateState.idle.applying(.progress(0.5)) == .idle)
        #expect(UpdateState.available("0.3.0").applying(.progress(0.5)) == .available("0.3.0"))
    }

    @Test("a verified download restarts the app")
    func downloadingToRestarting() {
        let state = UpdateState.downloading(version: "0.3.0", fraction: 1)
        #expect(state.applying(.downloadVerified) == .restarting(version: "0.3.0"))
    }

    @Test("an error fails the update from any state that knows a version")
    func anyStateToFailed() {
        let reason = UpdateFailureReason.noConnection
        #expect(UpdateState.available("0.3.0").applying(.failed(reason)) == .failed(version: "0.3.0", reason: reason))
        #expect(
            UpdateState.downloading(version: "0.3.0", fraction: 0.4).applying(.failed(reason))
                == .failed(version: "0.3.0", reason: reason)
        )
        #expect(
            UpdateState.restarting(version: "0.3.0").applying(.failed(.other))
                == .failed(version: "0.3.0", reason: .other)
        )
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
        #expect(UpdateState.available("0.3.0").applying(.foundNothing) == .idle)
    }

    @Test("a found version never interrupts a download or a restart")
    func checksDuringInstall() {
        let downloading = UpdateState.downloading(version: "0.3.0", fraction: 0.4)
        #expect(downloading.applying(.foundVersion("0.4.0")) == downloading)
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
        #expect(UpdateState.available("0.3.0").applying(.foundVersion("0.4.0")) == .available("0.4.0"))
        #expect(
            UpdateState.failed(version: "0.3.0", reason: .other).applying(.foundVersion("0.3.0"))
                == .available("0.3.0")
        )
    }
}

@Suite("Update state: values for the UI")
struct UpdateStateDerivedTests {
    @Test("the button shows in every state but idle")
    func buttonVisibility() {
        #expect(UpdateState.idle.button == nil)
        #expect(UpdateState.available("0.3.0").button != nil)
        #expect(UpdateState.downloading(version: "0.3.0", fraction: 0.4).button != nil)
        #expect(UpdateState.restarting(version: "0.3.0").button != nil)
        #expect(UpdateState.failed(version: "0.3.0", reason: .other).button != nil)
    }

    @Test("only available and failed accept clicks")
    func clickability() {
        #expect(UpdateState.available("0.3.0").button?.acceptsClicks == true)
        #expect(UpdateState.failed(version: "0.3.0", reason: .other).button?.acceptsClicks == true)
        #expect(UpdateState.downloading(version: "0.3.0", fraction: 0.4).button?.acceptsClicks == false)
        #expect(UpdateState.restarting(version: "0.3.0").button?.acceptsClicks == false)
    }

    @Test("labels: version, percent, restarting, retry")
    func labels() {
        #expect(UpdateState.available("0.3.0").button?.label == .version("0.3.0"))
        #expect(UpdateState.downloading(version: "0.3.0", fraction: 0.42).button?.label == .percent(42))
        #expect(UpdateState.downloading(version: "0.3.0", fraction: 0.996).button?.label == .percent(100))
        #expect(UpdateState.restarting(version: "0.3.0").button?.label == .restarting)
        #expect(UpdateState.failed(version: "0.3.0", reason: .other).button?.label == .retry)
    }

    @Test("the tooltip version names the update the click installs")
    func tooltipVersion() {
        #expect(UpdateState.available("0.3.0").button?.version == "0.3.0")
        #expect(UpdateState.failed(version: "0.3.0", reason: .other).button?.version == "0.3.0")
    }

    @Test("only failed has a failure line")
    func failureLine() {
        #expect(UpdateState.failed(version: "0.3.0", reason: .noConnection).failureReason == .noConnection)
        #expect(UpdateState.available("0.3.0").failureReason == nil)
        #expect(UpdateState.idle.failureReason == nil)
    }

    @Test("the update mark shows in available and failed only")
    func updateMark() {
        #expect(UpdateState.available("0.3.0").showsUpdateMark)
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
}

@Suite("Updater gate")
struct UpdaterGateTests {
    @Test("a Release version X.Y.Z starts the updater", arguments: ["0.4.0", "1.2.3", "10.20.300"])
    func release(version: String) {
        #expect(UpdaterGate.allows(shortVersion: version))
    }

    @Test(
        "dev builds and malformed versions never start it",
        arguments: ["0.0.0-dev.12", "0.0.0-dev", "0.1", "1.2.3.4", "v1.2.3", "1.2.x", "1..3", " 1.2.3", ""]
    )
    func notRelease(version: String) {
        #expect(!UpdaterGate.allows(shortVersion: version))
    }
}
