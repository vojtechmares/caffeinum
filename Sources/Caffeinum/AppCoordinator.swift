import AppKit
import Combine
import Foundation

/// Wires the preferences to the pieces that act on them: the `caffeinate`
/// process, the `pmset` schedule, the login item and the global hot key.
@MainActor
final class AppCoordinator: ObservableObject {

    static let shared = AppCoordinator()

    let preferences: Preferences
    let caffeinate: CaffeinateController
    let schedule: PowerScheduleController
    let loginItem: LoginItemController

    private let hotKeys = HotKeyManager.shared
    private var cancellables: Set<AnyCancellable> = []
    private var lastSessionSignature: String

    private init() {
        let preferences = Preferences()
        self.preferences = preferences
        self.caffeinate = CaffeinateController()
        self.schedule = PowerScheduleController()
        self.loginItem = LoginItemController()
        self.lastSessionSignature = preferences.sessionSignature

        // Re-publish the children so a single @ObservedObject on the menu redraws
        // for any change, and react to preference edits once they have landed.
        for child in [preferences.objectWillChange,
                      caffeinate.objectWillChange,
                      schedule.objectWillChange,
                      loginItem.objectWillChange] {
            child
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.preferencesDidChange() }
            .store(in: &cancellables)

        syncHotKey()

        if preferences.restoreOnLaunch && preferences.wasAwakeAtQuit {
            setAwake(true)
        }
    }

    // MARK: - keep awake

    var isAwake: Bool { caffeinate.isActive }

    func setAwake(_ awake: Bool) {
        if awake {
            caffeinate.start(flags: preferences.caffeinateFlags, endDate: currentEndDate())
        } else {
            caffeinate.stop()
        }
        preferences.wasAwakeAtQuit = caffeinate.isActive
    }

    func toggleAwake() {
        setAwake(!caffeinate.isActive)
    }

    private func currentEndDate() -> Date? {
        preferences.duration.endDate(untilTime: preferences.untilTime)
    }

    // MARK: - schedule

    func applySchedule() async {
        let wake = preferences.wakeEnabled ? preferences.wakeTime : nil
        let sleep = preferences.sleepEnabled ? preferences.sleepTime : nil
        let applied = await schedule.apply(wake: wake, sleep: sleep, days: preferences.scheduleDays)
        if applied {
            preferences.appliedScheduleSignature = preferences.scheduleSignature
        }
    }

    func clearRepeatingSchedule() async {
        let cleared = await schedule.cancelRepeating()
        if cleared {
            preferences.wakeEnabled = false
            preferences.sleepEnabled = false
            preferences.appliedScheduleSignature = preferences.scheduleSignature
        }
    }

    func clearOneTimeEvents() async {
        await schedule.cancelOneTimeEvents()
    }

    // MARK: - reactions

    private func preferencesDidChange() {
        let signature = preferences.sessionSignature
        if signature != lastSessionSignature {
            lastSessionSignature = signature
            caffeinate.restart(flags: preferences.caffeinateFlags, endDate: currentEndDate())
        }
        syncHotKey()
    }

    private func syncHotKey() {
        guard preferences.hotKeyEnabled, preferences.hotKey.isValid else {
            hotKeys.unregister()
            return
        }
        hotKeys.register(preferences.hotKey) { [weak self] in
            self?.toggleAwake()
        }
    }

    // MARK: - menu bar presentation

    var menuBarSymbol: String {
        caffeinate.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
    }

    var menuBarCountdown: String? {
        guard caffeinate.isActive else { return nil }
        return caffeinate.remainingDescription
    }

    var statusDescription: String {
        guard caffeinate.isActive else { return "Your Mac sleeps normally." }
        if let remaining = caffeinate.remainingDescription {
            return "Awake for another \(remaining)."
        }
        return "Awake until you turn this off."
    }

    func applicationWillTerminate() {
        // Persist the running state before tearing the session down.
        preferences.wasAwakeAtQuit = caffeinate.isActive
        caffeinate.stop()
        hotKeys.unregister()
    }
}
