import Combine
import Foundation

/// Everything the user can configure, mirrored into `UserDefaults` on every change.
///
/// Property observers do not fire during initialisation, so loading in `init`
/// deliberately does not write back what it just read.
@MainActor
final class Preferences: ObservableObject {

    private enum Key: String {
        case preventDisplaySleep, preventIdleSleep, preventDiskSleep, preventSystemSleep
        case duration, untilHour, untilMinute
        case restoreOnLaunch, wasAwakeAtQuit
        case wakeEnabled, wakeHour, wakeMinute
        case sleepEnabled, sleepHour, sleepMinute
        case scheduleDays, appliedScheduleSignature
        case hotKeyEnabled, hotKeyCode, hotKeyModifiers
    }

    private let store: UserDefaults

    // MARK: - caffeinate assertions

    @Published var preventDisplaySleep = true { didSet { write(.preventDisplaySleep, preventDisplaySleep) } }
    @Published var preventIdleSleep = true { didSet { write(.preventIdleSleep, preventIdleSleep) } }
    @Published var preventDiskSleep = false { didSet { write(.preventDiskSleep, preventDiskSleep) } }
    @Published var preventSystemSleep = false { didSet { write(.preventSystemSleep, preventSystemSleep) } }

    @Published var duration: AwakeDuration = .indefinite { didSet { write(.duration, duration.rawValue) } }
    @Published var untilTime = TimeOfDay(hour: 18, minute: 0) {
        didSet {
            write(.untilHour, untilTime.hour)
            write(.untilMinute, untilTime.minute)
        }
    }

    // MARK: - behaviour

    @Published var restoreOnLaunch = true { didSet { write(.restoreOnLaunch, restoreOnLaunch) } }
    @Published var wasAwakeAtQuit = false { didSet { write(.wasAwakeAtQuit, wasAwakeAtQuit) } }

    // MARK: - schedule

    @Published var wakeEnabled = false { didSet { write(.wakeEnabled, wakeEnabled) } }
    @Published var wakeTime = TimeOfDay(hour: 8, minute: 0) {
        didSet {
            write(.wakeHour, wakeTime.hour)
            write(.wakeMinute, wakeTime.minute)
        }
    }

    @Published var sleepEnabled = false { didSet { write(.sleepEnabled, sleepEnabled) } }
    @Published var sleepTime = TimeOfDay(hour: 23, minute: 30) {
        didSet {
            write(.sleepHour, sleepTime.hour)
            write(.sleepMinute, sleepTime.minute)
        }
    }

    @Published var scheduleDays: Set<Weekday> = Weekday.everyDay {
        didSet { write(.scheduleDays, scheduleDays.pmsetLetters) }
    }

    /// Signature of the schedule the last successful `pmset repeat` actually applied,
    /// so the UI can tell edited-but-not-applied from in-sync.
    @Published var appliedScheduleSignature = "" {
        didSet { write(.appliedScheduleSignature, appliedScheduleSignature) }
    }

    // MARK: - global hot key

    @Published var hotKeyEnabled = false { didSet { write(.hotKeyEnabled, hotKeyEnabled) } }
    @Published var hotKey = HotKeyCombo.default {
        didSet {
            write(.hotKeyCode, Int(hotKey.keyCode))
            write(.hotKeyModifiers, Int(hotKey.carbonModifiers))
        }
    }

    // MARK: - lifecycle

    init(store: UserDefaults = .standard) {
        self.store = store

        store.register(defaults: [
            Key.preventDisplaySleep.rawValue: true,
            Key.preventIdleSleep.rawValue: true,
            Key.restoreOnLaunch.rawValue: true,
            Key.duration.rawValue: AwakeDuration.indefinite.rawValue,
            Key.untilHour.rawValue: 18,
            Key.untilMinute.rawValue: 0,
            Key.wakeHour.rawValue: 8,
            Key.wakeMinute.rawValue: 0,
            Key.sleepHour.rawValue: 23,
            Key.sleepMinute.rawValue: 30,
            Key.scheduleDays.rawValue: Weekday.everyDay.pmsetLetters,
            Key.appliedScheduleSignature.rawValue: Self.emptyScheduleSignature,
            Key.hotKeyCode.rawValue: Int(HotKeyCombo.default.keyCode),
            Key.hotKeyModifiers.rawValue: Int(HotKeyCombo.default.carbonModifiers),
        ])

        preventDisplaySleep = store.bool(forKey: Key.preventDisplaySleep.rawValue)
        preventIdleSleep = store.bool(forKey: Key.preventIdleSleep.rawValue)
        preventDiskSleep = store.bool(forKey: Key.preventDiskSleep.rawValue)
        preventSystemSleep = store.bool(forKey: Key.preventSystemSleep.rawValue)

        duration = AwakeDuration(rawValue: store.string(forKey: Key.duration.rawValue) ?? "") ?? .indefinite
        untilTime = TimeOfDay(hour: store.integer(forKey: Key.untilHour.rawValue),
                              minute: store.integer(forKey: Key.untilMinute.rawValue))

        restoreOnLaunch = store.bool(forKey: Key.restoreOnLaunch.rawValue)
        wasAwakeAtQuit = store.bool(forKey: Key.wasAwakeAtQuit.rawValue)

        wakeEnabled = store.bool(forKey: Key.wakeEnabled.rawValue)
        wakeTime = TimeOfDay(hour: store.integer(forKey: Key.wakeHour.rawValue),
                             minute: store.integer(forKey: Key.wakeMinute.rawValue))
        sleepEnabled = store.bool(forKey: Key.sleepEnabled.rawValue)
        sleepTime = TimeOfDay(hour: store.integer(forKey: Key.sleepHour.rawValue),
                              minute: store.integer(forKey: Key.sleepMinute.rawValue))
        scheduleDays = Weekday.days(fromPmsetLetters: store.string(forKey: Key.scheduleDays.rawValue) ?? "")
        appliedScheduleSignature = store.string(forKey: Key.appliedScheduleSignature.rawValue) ?? ""

        hotKeyEnabled = store.bool(forKey: Key.hotKeyEnabled.rawValue)
        hotKey = HotKeyCombo(keyCode: UInt32(store.integer(forKey: Key.hotKeyCode.rawValue)),
                             carbonModifiers: UInt32(store.integer(forKey: Key.hotKeyModifiers.rawValue)))
    }

    private func write(_ key: Key, _ value: Any) {
        store.set(value, forKey: key.rawValue)
    }

    // MARK: - derived

    /// Flags for `caffeinate`, in the order the man page lists them.
    ///
    /// With no flags at all `caffeinate` prevents idle sleep anyway, so an empty
    /// selection is spelled out as `-i` rather than left implicit.
    var caffeinateFlags: [String] {
        var flags: [String] = []
        if preventDisplaySleep { flags.append("-d") }
        if preventIdleSleep { flags.append("-i") }
        if preventDiskSleep { flags.append("-m") }
        if preventSystemSleep { flags.append("-s") }
        return flags.isEmpty ? ["-i"] : flags
    }

    /// The command line as the user would type it, shown in the UI.
    var caffeinateCommandPreview: String {
        (["caffeinate"] + caffeinateFlags).joined(separator: " ")
    }

    /// Changing any of these while a session is running means restarting `caffeinate`.
    var sessionSignature: String {
        caffeinateFlags.joined() + "|" + duration.rawValue + "|" + untilTime.pmsetTime
    }

    /// Collapses to a single value when nothing is scheduled, so a fresh install -
    /// where no schedule exists and none is wanted - does not read as pending.
    var scheduleSignature: String {
        guard wakeEnabled || sleepEnabled else { return Self.emptyScheduleSignature }
        return [
            wakeEnabled ? "wake:\(wakeTime.pmsetTime)" : "wake:off",
            sleepEnabled ? "sleep:\(sleepTime.pmsetTime)" : "sleep:off",
            "days:\(scheduleDays.pmsetLetters)",
        ].joined(separator: "|")
    }

    static let emptyScheduleSignature = "off"

    /// True when the schedule shown in the UI is not what was last handed to `pmset`.
    var scheduleNeedsApplying: Bool {
        scheduleSignature != appliedScheduleSignature
    }

    /// `pmset repeat` refuses an empty weekday list, so guard the Apply button.
    var scheduleIsValid: Bool {
        (!wakeEnabled && !sleepEnabled) || !scheduleDays.isEmpty
    }
}
