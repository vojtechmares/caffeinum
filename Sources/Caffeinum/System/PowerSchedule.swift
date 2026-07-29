import Foundation

/// One line of `pmset -g sched` output.
struct PowerEvent: Identifiable, Hashable {
    let id = UUID()
    /// e.g. "wakeorpoweron at 8:00AM every day"
    var summary: String
    /// The bundle or process that asked for it, when pmset reports one.
    var owner: String?

    static func == (lhs: PowerEvent, rhs: PowerEvent) -> Bool {
        lhs.summary == rhs.summary && lhs.owner == rhs.owner
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(summary)
        hasher.combine(owner)
    }
}

struct ScheduleReport {
    var repeating: [PowerEvent] = []
    var oneTime: [PowerEvent] = []

    var isEmpty: Bool { repeating.isEmpty && oneTime.isEmpty }
    static let empty = ScheduleReport()
}

/// Builds and reads the system sleep/wake schedule via `pmset`.
///
/// Reading is unprivileged; every mutation needs root and therefore goes
/// through `PrivilegedShell`.
enum PowerSchedule {

    static let executable = "/usr/bin/pmset"

    // MARK: - commands

    /// A single `pmset repeat` call sets the whole repeating schedule, replacing
    /// whatever was there, so wake and sleep always have to be sent together.
    static func repeatCommand(wake: TimeOfDay?, sleep: TimeOfDay?, days: Set<Weekday>) -> String {
        var parts: [String] = []
        let letters = days.pmsetLetters

        if let wake, !letters.isEmpty {
            parts += ["wakeorpoweron", letters, wake.pmsetTime]
        }
        if let sleep, !letters.isEmpty {
            parts += ["sleep", letters, sleep.pmsetTime]
        }

        guard !parts.isEmpty else { return "\(executable) repeat cancel" }
        return ([executable, "repeat"] + parts).joined(separator: " ")
    }

    static let cancelRepeatingCommand = "\(executable) repeat cancel"
    static let cancelOneTimeCommand = "\(executable) schedule cancelall"

    /// Human readable version of what a schedule will do, for the UI.
    static func description(wake: TimeOfDay?, sleep: TimeOfDay?, days: Set<Weekday>) -> String {
        guard wake != nil || sleep != nil else { return "No repeating schedule." }
        guard !days.isEmpty else { return "Pick at least one day." }

        var clauses: [String] = []
        if let wake { clauses.append("wake at \(wake.displayString)") }
        if let sleep { clauses.append("sleep at \(sleep.displayString)") }
        return clauses.joined(separator: ", ") + " " + days.shortDescription + "."
    }

    // MARK: - reading

    static func read() -> ScheduleReport {
        let result = Shell.run(executable, ["-g", "sched"])
        guard result.status == 0 else { return .empty }
        return parse(result.standardOutput)
    }

    /// `pmset -g sched` prints up to two labelled sections:
    ///
    ///     Repeating power events:
    ///       wakeorpoweron at 8:00AM every day
    ///     Scheduled power events:
    ///      [0]  wake at 07/29/2026 13:00:00 by 'com.apple.alarm…' User visible: true
    static func parse(_ output: String) -> ScheduleReport {
        var report = ScheduleReport()
        var section: WritableKeyPath<ScheduleReport, [PowerEvent]>?

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("Repeating power events") {
                section = \.repeating
                continue
            }
            if line.hasPrefix("Scheduled power events") {
                section = \.oneTime
                continue
            }
            guard let section, let event = parseEvent(line) else { continue }
            report[keyPath: section].append(event)
        }
        return report
    }

    private static func parseEvent(_ line: String) -> PowerEvent? {
        // Strip the "[0]" index the one-time section prefixes each entry with.
        var body = line
        if body.hasPrefix("["), let close = body.firstIndex(of: "]") {
            body = String(body[body.index(after: close)...])
        }
        body = body.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }

        guard let ownerRange = body.range(of: " by '") else {
            return PowerEvent(summary: body, owner: nil)
        }
        let summary = String(body[..<ownerRange.lowerBound])
        var owner = String(body[ownerRange.upperBound...])
        if let end = owner.range(of: "'") {
            owner = String(owner[..<end.lowerBound])
        }
        return PowerEvent(summary: summary, owner: owner.isEmpty ? nil : owner)
    }
}
