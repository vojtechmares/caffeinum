import Foundation

/// How long a keep-awake session should last once started.
enum AwakeDuration: String, CaseIterable, Identifiable {
    case indefinite
    case minutes15
    case minutes30
    case hour1
    case hour2
    case hour5
    case untilTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .indefinite: return "Indefinitely"
        case .minutes15: return "15 minutes"
        case .minutes30: return "30 minutes"
        case .hour1: return "1 hour"
        case .hour2: return "2 hours"
        case .hour5: return "5 hours"
        case .untilTime: return "Until…"
        }
    }

    /// Fixed length in seconds, or nil for the two open-ended cases.
    var seconds: TimeInterval? {
        switch self {
        case .indefinite, .untilTime: return nil
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hour1: return 3600
        case .hour2: return 2 * 3600
        case .hour5: return 5 * 3600
        }
    }

    /// When a session started now would end, or nil if it should run until stopped.
    func endDate(untilTime: TimeOfDay, from reference: Date = Date()) -> Date? {
        switch self {
        case .indefinite: return nil
        case .untilTime: return untilTime.nextOccurrence(after: reference)
        default: return seconds.map { reference.addingTimeInterval($0) }
        }
    }
}
