import Combine
import Foundation

/// Applies and reports the system power schedule, keeping the privileged calls
/// off the main actor so the authentication dialog never blocks the UI.
@MainActor
final class PowerScheduleController: ObservableObject {

    @Published private(set) var report = ScheduleReport.empty
    @Published private(set) var isApplying = false
    @Published var lastError: String?

    private let authenticationPrompt =
        "Caffeinum needs administrator access to change the system sleep and wake schedule."

    init() {
        refresh()
    }

    func refresh() {
        report = PowerSchedule.read()
    }

    /// Sends the whole repeating schedule to `pmset`. Returns true when it stuck,
    /// so the caller can record the applied signature.
    @discardableResult
    func apply(wake: TimeOfDay?, sleep: TimeOfDay?, days: Set<Weekday>) async -> Bool {
        await run(PowerSchedule.repeatCommand(wake: wake, sleep: sleep, days: days))
    }

    @discardableResult
    func cancelRepeating() async -> Bool {
        await run(PowerSchedule.cancelRepeatingCommand)
    }

    @discardableResult
    func cancelOneTimeEvents() async -> Bool {
        await run(PowerSchedule.cancelOneTimeCommand)
    }

    private func run(_ command: String) async -> Bool {
        guard !isApplying else { return false }
        isApplying = true
        lastError = nil

        let prompt = authenticationPrompt
        let succeeded: Bool
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try PrivilegedShell.run(command, prompt: prompt)
            }.value
            succeeded = true
        } catch PrivilegedShellError.cancelled {
            succeeded = false
        } catch {
            lastError = error.localizedDescription
            succeeded = false
        }

        isApplying = false
        refresh()
        return succeeded
    }
}
