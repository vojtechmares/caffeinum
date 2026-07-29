import Foundation

/// A day of the week, ordered Monday-first and able to render itself as the
/// single letter `pmset` expects in its `weekdays` argument (a subset of MTWRFSU).
enum Weekday: Int, CaseIterable, Identifiable, Comparable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Thursday is R and Sunday is U so that every day gets a distinct letter.
    var pmsetLetter: Character {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "R"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "U"
        }
    }

    /// What the day is labelled with in the picker - the human initial, not the pmset one.
    var initial: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }

    var name: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let everyDay: Set<Weekday> = Set(allCases)

    static func days(fromPmsetLetters letters: String) -> Set<Weekday> {
        Set(allCases.filter { letters.contains($0.pmsetLetter) })
    }
}

extension Set where Element == Weekday {
    /// Canonical MTWRFSU-ordered letters for `pmset repeat`.
    var pmsetLetters: String {
        String(Weekday.allCases.filter(contains).map(\.pmsetLetter))
    }

    var shortDescription: String {
        if self == Weekday.everyDay { return "every day" }
        if self == Weekday.weekdays { return "weekdays" }
        if self == [.saturday, .sunday] { return "weekends" }
        if isEmpty { return "no days" }
        return Weekday.allCases.filter(contains).map(\.initial).joined(separator: " ")
    }
}

/// An hour and minute with no date attached - what a repeating power event needs.
struct TimeOfDay: Equatable, Hashable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// `pmset` wants HH:mm:ss in 24 hour format.
    var pmsetTime: String { String(format: "%02d:%02d:00", hour, minute) }

    /// Today's occurrence of this time, used to drive `DatePicker`.
    func date(on day: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// The next moment this time comes around, used by the "stay awake until" duration.
    func nextOccurrence(after reference: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = date(on: reference, calendar: calendar)
        if today > reference { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
    }

    var displayString: String {
        TimeOfDay.formatter.string(from: date())
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
