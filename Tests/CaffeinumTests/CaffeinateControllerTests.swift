import Foundation
import Testing
@testable import Caffeinum

/// End-to-end checks against the real `caffeinate` binary and the real assertion
/// list, because that interaction is the whole point of the app. Serialized so
/// concurrent tests do not see each other's `caffeinate` processes.
@Suite("CaffeinateController", .serialized)
@MainActor
struct CaffeinateControllerTests {

    private func assertions() -> String {
        Shell.run(PowerSchedule.executable, ["-g", "assertions"]).standardOutput
    }

    @Test("starting holds a real power assertion and stopping releases it")
    func assertionLifecycle() async throws {
        let controller = CaffeinateController()
        controller.start(flags: ["-d", "-i"], endDate: nil)

        #expect(controller.isActive)
        let pid = try #require(controller.processIdentifier)

        try await Task.sleep(nanoseconds: 800_000_000)
        #expect(assertions().contains("pid \(pid)(caffeinate)"),
                "caffeinate should show up in pmset -g assertions")

        controller.stop()
        #expect(!controller.isActive)
        #expect(controller.endDate == nil)

        try await Task.sleep(nanoseconds: 800_000_000)
        #expect(!assertions().contains("pid \(pid)(caffeinate)"),
                "the assertion should be released once caffeinate is terminated")
    }

    @Test("a timed session ends on its own")
    func timedSession() async throws {
        let controller = CaffeinateController()
        controller.start(flags: ["-i"], endDate: Date().addingTimeInterval(1))
        let pid = try #require(controller.processIdentifier)
        #expect(controller.remainingDescription != nil)

        try await Task.sleep(nanoseconds: 2_500_000_000)
        #expect(!controller.isActive, "the expiry timer should have stopped the session")
        #expect(!assertions().contains("pid \(pid)(caffeinate)"))
    }

    @Test("restart replaces the process, but only while active")
    func restart() async throws {
        let controller = CaffeinateController()

        controller.restart(flags: ["-i"], endDate: nil)
        #expect(!controller.isActive, "restart must not start an inactive session")

        controller.start(flags: ["-i"], endDate: nil)
        let first = try #require(controller.processIdentifier)
        controller.restart(flags: ["-d", "-i"], endDate: nil)
        let second = try #require(controller.processIdentifier)

        #expect(first != second)
        #expect(controller.isActive)

        controller.stop()
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    @Test("the countdown reflects the end date")
    func countdown() throws {
        let controller = CaffeinateController()
        controller.start(flags: ["-i"], endDate: Date().addingTimeInterval(3600))
        defer { controller.stop() }

        let remaining = try #require(controller.remaining)
        #expect(abs(remaining - 3600) < 5)
        #expect(controller.remainingDescription == "1h 0m")
    }
}
