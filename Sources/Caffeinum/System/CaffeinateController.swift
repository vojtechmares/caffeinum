import Combine
import Foundation

/// Owns the one `caffeinate` child process that holds the power assertions.
///
/// The process is always launched with `-w <our pid>` so that if Caffeinum is
/// force quit or crashes, `caffeinate` releases its assertions and exits too
/// rather than leaving the Mac awake forever. Timed sessions are ended by a
/// timer here instead of `caffeinate -t`, so the countdown and the process
/// always agree on when time is up.
@MainActor
final class CaffeinateController: ObservableObject {

    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?
    /// Bumped once a second while active purely so the countdown redraws.
    @Published private(set) var tick = Date()

    /// pid of the running `caffeinate`, which is also what `pmset -g assertions` reports.
    var processIdentifier: Int32? { process?.processIdentifier }

    private static let executable = "/usr/bin/caffeinate"

    private var process: Process?
    private var expiryTimer: Timer?
    private var tickTimer: Timer?

    var remaining: TimeInterval? {
        guard let endDate else { return nil }
        return max(0, endDate.timeIntervalSince(tick))
    }

    /// "1h 23m", or nil when the session has no end.
    var remainingDescription: String? {
        guard let remaining else { return nil }
        return Self.format(remaining)
    }

    func start(flags: [String], endDate: Date?) {
        stop()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.executable)
        process.arguments = flags + ["-w", String(ProcessInfo.processInfo.processIdentifier)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in
            Task { @MainActor [weak self] in self?.processDidTerminate() }
        }

        do {
            try process.run()
        } catch {
            NSLog("Caffeinum: could not launch caffeinate: \(error.localizedDescription)")
            return
        }

        self.process = process
        self.endDate = endDate
        self.tick = Date()
        isActive = true

        if let endDate {
            let expiry = Timer(fire: endDate, interval: 0, repeats: false) { _ in
                Task { @MainActor [weak self] in self?.stop() }
            }
            RunLoop.main.add(expiry, forMode: .common)
            expiryTimer = expiry

            let ticker = Timer(timeInterval: 1, repeats: true) { _ in
                Task { @MainActor [weak self] in self?.tick = Date() }
            }
            RunLoop.main.add(ticker, forMode: .common)
            tickTimer = ticker
        }
    }

    func stop() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        tickTimer?.invalidate()
        tickTimer = nil

        if let process, process.isRunning {
            // Clear the handler first: this is a deliberate stop, not the process dying on us.
            process.terminationHandler = nil
            process.terminate()
        }
        process = nil
        endDate = nil
        isActive = false
    }

    /// Applies changed options to a session that is already running.
    func restart(flags: [String], endDate: Date?) {
        guard isActive else { return }
        start(flags: flags, endDate: endDate)
    }

    /// `caffeinate` went away without us asking - keep the UI honest.
    private func processDidTerminate() {
        guard isActive else { return }
        stop()
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }
}
