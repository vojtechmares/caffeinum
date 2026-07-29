import Foundation
import Testing
@testable import Caffeinum

@Suite("Weekday")
struct WeekdayTests {

    @Test("letters come out in canonical MTWRFSU order")
    func canonicalOrder() {
        #expect(Weekday.everyDay.pmsetLetters == "MTWRFSU")
        #expect(Weekday.weekdays.pmsetLetters == "MTWRF")
        #expect(Set<Weekday>([.sunday, .monday]).pmsetLetters == "MU")
    }

    @Test("every day gets a distinct letter")
    func distinctLetters() {
        #expect(Set(Weekday.allCases.map(\.pmsetLetter)).count == 7)
    }

    @Test("days round-trip through their letters")
    func roundTrip() {
        let days: Set<Weekday> = [.tuesday, .thursday, .saturday]
        #expect(Weekday.days(fromPmsetLetters: days.pmsetLetters) == days)
    }

    @Test("common selections get friendly names")
    func shortDescription() {
        #expect(Weekday.everyDay.shortDescription == "every day")
        #expect(Weekday.weekdays.shortDescription == "weekdays")
        #expect(Set<Weekday>([.saturday, .sunday]).shortDescription == "weekends")
    }
}

@Suite("TimeOfDay")
struct TimeOfDayTests {

    @Test("pmset format is zero-padded 24 hour")
    func pmsetFormat() {
        #expect(TimeOfDay(hour: 8, minute: 5).pmsetTime == "08:05:00")
        #expect(TimeOfDay(hour: 23, minute: 30).pmsetTime == "23:30:00")
    }

    @Test("out of range values are clamped")
    func clamping() {
        #expect(TimeOfDay(hour: 99, minute: -4).pmsetTime == "23:00:00")
    }

    @Test("the next occurrence rolls to tomorrow once the time has passed")
    func nextOccurrence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29, hour: 12))!

        let laterToday = TimeOfDay(hour: 18, minute: 0).nextOccurrence(after: noon, calendar: calendar)
        #expect(calendar.dateComponents([.day], from: laterToday).day == 29)

        let alreadyPassed = TimeOfDay(hour: 9, minute: 0).nextOccurrence(after: noon, calendar: calendar)
        #expect(calendar.dateComponents([.day], from: alreadyPassed).day == 30)
    }
}

@Suite("AwakeDuration")
struct AwakeDurationTests {

    @Test("fixed durations end that many seconds from now")
    func fixedDuration() {
        let now = Date()
        #expect(AwakeDuration.hour2.endDate(untilTime: TimeOfDay(hour: 0, minute: 0), from: now)
                == now.addingTimeInterval(7200))
    }

    @Test("indefinite has no end")
    func indefinite() {
        #expect(AwakeDuration.indefinite.endDate(untilTime: TimeOfDay(hour: 0, minute: 0)) == nil)
    }

    @Test("until-time uses the next occurrence of that time")
    func untilTime() throws {
        let end = try #require(AwakeDuration.untilTime.endDate(untilTime: TimeOfDay(hour: 18, minute: 0)))
        #expect(end > Date())
    }
}

@Suite("HotKeyCombo")
struct HotKeyComboTests {

    @Test("the default shortcut is ⌃⌥⌘C")
    func defaultCombo() {
        #expect(HotKeyCombo.default.displayString == "⌃⌥⌘C")
        #expect(HotKeyCombo.default.isValid)
    }

    @Test("shift alone is not a valid global shortcut")
    func shiftAlone() {
        #expect(!HotKeyCombo(keyCode: 8, carbonModifiers: 512).isValid)
    }
}

@Suite("Preferences")
@MainActor
struct PreferencesTests {

    private func makePreferences() -> Preferences {
        let suite = UserDefaults(suiteName: "cz.mares.caffeinum.tests.\(UUID().uuidString)")!
        return Preferences(store: suite)
    }

    @Test("flags follow the toggles, in man page order")
    func flags() {
        let preferences = makePreferences()
        preferences.preventDisplaySleep = true
        preferences.preventIdleSleep = true
        preferences.preventDiskSleep = true
        preferences.preventSystemSleep = true
        #expect(preferences.caffeinateFlags == ["-d", "-i", "-m", "-s"])
        #expect(preferences.caffeinateCommandPreview == "caffeinate -d -i -m -s")
    }

    @Test("no toggles falls back to caffeinate's own default")
    func noFlags() {
        let preferences = makePreferences()
        preferences.preventDisplaySleep = false
        preferences.preventIdleSleep = false
        preferences.preventDiskSleep = false
        preferences.preventSystemSleep = false
        #expect(preferences.caffeinateFlags == ["-i"])
    }

    @Test("values survive a reload")
    func persistence() {
        let suite = UserDefaults(suiteName: "cz.mares.caffeinum.tests.\(UUID().uuidString)")!
        let first = Preferences(store: suite)
        first.wakeEnabled = true
        first.wakeTime = TimeOfDay(hour: 7, minute: 45)
        first.scheduleDays = Weekday.weekdays
        first.duration = .hour2

        let second = Preferences(store: suite)
        #expect(second.wakeEnabled)
        #expect(second.wakeTime == TimeOfDay(hour: 7, minute: 45))
        #expect(second.scheduleDays == Weekday.weekdays)
        #expect(second.duration == .hour2)
    }

    @Test("a fresh install with nothing scheduled has nothing to apply")
    func freshInstallIsClean() {
        let preferences = makePreferences()
        #expect(!preferences.wakeEnabled)
        #expect(!preferences.sleepEnabled)
        #expect(!preferences.scheduleNeedsApplying)
    }

    @Test("turning the whole schedule off again reads as pending")
    func turningEverythingOff() {
        let preferences = makePreferences()
        preferences.wakeEnabled = true
        preferences.appliedScheduleSignature = preferences.scheduleSignature

        preferences.wakeEnabled = false
        #expect(preferences.scheduleNeedsApplying, "the pmset schedule still needs cancelling")
    }

    @Test("the schedule reads as dirty until its signature is recorded")
    func dirtyTracking() {
        let preferences = makePreferences()
        preferences.wakeEnabled = true
        #expect(preferences.scheduleNeedsApplying)

        preferences.appliedScheduleSignature = preferences.scheduleSignature
        #expect(!preferences.scheduleNeedsApplying)

        preferences.wakeTime = TimeOfDay(hour: 9, minute: 0)
        #expect(preferences.scheduleNeedsApplying)
    }

    @Test("an empty day selection is invalid only when something is scheduled")
    func dayValidation() {
        let preferences = makePreferences()
        preferences.scheduleDays = []
        #expect(preferences.scheduleIsValid)

        preferences.wakeEnabled = true
        #expect(!preferences.scheduleIsValid)
    }
}
