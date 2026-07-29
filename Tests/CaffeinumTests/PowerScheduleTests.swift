import Testing
@testable import Caffeinum

@Suite("pmset command building")
struct PowerScheduleCommandTests {

    @Test("wake and sleep go into a single repeat command")
    func wakeAndSleep() {
        let command = PowerSchedule.repeatCommand(
            wake: TimeOfDay(hour: 8, minute: 0),
            sleep: TimeOfDay(hour: 23, minute: 30),
            days: Weekday.weekdays
        )
        #expect(command == "/usr/bin/pmset repeat wakeorpoweron MTWRF 08:00:00 sleep MTWRF 23:30:00")
    }

    @Test("wake only")
    func wakeOnly() {
        let command = PowerSchedule.repeatCommand(
            wake: TimeOfDay(hour: 6, minute: 5),
            sleep: nil,
            days: [.sunday]
        )
        #expect(command == "/usr/bin/pmset repeat wakeorpoweron U 06:05:00")
    }

    @Test("sleep only")
    func sleepOnly() {
        let command = PowerSchedule.repeatCommand(
            wake: nil,
            sleep: TimeOfDay(hour: 22, minute: 15),
            days: Weekday.everyDay
        )
        #expect(command == "/usr/bin/pmset repeat sleep MTWRFSU 22:15:00")
    }

    @Test("nothing enabled cancels the repeating schedule")
    func nothingEnabled() {
        #expect(PowerSchedule.repeatCommand(wake: nil, sleep: nil, days: Weekday.everyDay)
                == "/usr/bin/pmset repeat cancel")
    }

    @Test("no days selected cancels rather than emitting an empty weekday list")
    func noDays() {
        #expect(PowerSchedule.repeatCommand(wake: TimeOfDay(hour: 8, minute: 0), sleep: nil, days: [])
                == "/usr/bin/pmset repeat cancel")
    }
}

@Suite("pmset -g sched parsing")
struct PowerScheduleParsingTests {

    @Test("both sections are picked up")
    func bothSections() {
        let output = """
            Repeating power events:
              wakepoweron at 8:00AM every day
              sleep at 11:30PM weekdays only
            Scheduled power events:
             [0]  wake at 07/29/2026 13:00:00 by 'com.apple.alarm.user-visible-x' User visible: true
             [1]  sleep at 07/30/2026 01:52:45 by 'com.apple.osanalytics'
            """

        let report = PowerSchedule.parse(output)

        #expect(report.repeating.count == 2)
        #expect(report.repeating[0].summary == "wakepoweron at 8:00AM every day")
        #expect(report.repeating[0].owner == nil)

        #expect(report.oneTime.count == 2)
        #expect(report.oneTime[0].summary == "wake at 07/29/2026 13:00:00")
        #expect(report.oneTime[0].owner == "com.apple.alarm.user-visible-x")
        #expect(report.oneTime[1].owner == "com.apple.osanalytics")
    }

    @Test("empty output parses to an empty report")
    func emptyOutput() {
        #expect(PowerSchedule.parse("").isEmpty)
    }

    /// The real `pmset -g sched` has to stay parseable, so read it for real.
    @Test("the live schedule parses cleanly")
    func liveSchedule() {
        let report = PowerSchedule.read()
        for event in report.repeating + report.oneTime {
            #expect(!event.summary.isEmpty)
            #expect(!event.summary.hasPrefix("["), "the index prefix should be stripped")
        }
    }
}
