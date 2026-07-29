import AppKit
import SwiftUI

/// The whole UI: one panel hanging off the menu bar icon.
struct MenuContentView: View {

    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var preferences: Preferences
    @ObservedObject private var caffeinate: CaffeinateController
    @ObservedObject private var schedule: PowerScheduleController
    @ObservedObject private var loginItem: LoginItemController

    @State private var showEvents: Bool

    init(coordinator: AppCoordinator, showingEvents: Bool = false) {
        self.coordinator = coordinator
        self.preferences = coordinator.preferences
        self.caffeinate = coordinator.caffeinate
        self.schedule = coordinator.schedule
        self.loginItem = coordinator.loginItem
        _showEvents = State(initialValue: showingEvents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            awakeToggle
            Divider()
            awakeOptions
            Divider()
            scheduleSection
            Divider()
            eventsSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 296)
        .onAppear {
            schedule.refresh()
            loginItem.refresh()
        }
    }

    // MARK: - keep awake

    private var awakeToggle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(isOn: Binding(get: { caffeinate.isActive },
                                 set: { coordinator.setAwake($0) })) {
                Text("Keep awake").font(.system(size: 13, weight: .semibold))
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Text(coordinator.statusDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var awakeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "While awake")

            VStack(alignment: .leading, spacing: 4) {
                FlagToggle(title: "Prevent display sleep", flag: "-d",
                           isOn: $preferences.preventDisplaySleep)
                FlagToggle(title: "Prevent idle sleep", flag: "-i",
                           isOn: $preferences.preventIdleSleep)
                FlagToggle(title: "Prevent disk idle sleep", flag: "-m",
                           isOn: $preferences.preventDiskSleep)
                FlagToggle(title: "Prevent sleep on AC power", flag: "-s",
                           isOn: $preferences.preventSystemSleep)
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                Text("For")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("", selection: $preferences.duration) {
                    ForEach(AwakeDuration.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .labelsHidden()
                .controlSize(.small)

                if preferences.duration == .untilTime {
                    DatePicker("", selection: TimeOfDay.binding($preferences.untilTime),
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .controlSize(.small)
                }
            }

            Text(preferences.caffeinateCommandPreview)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Daily schedule")

            scheduleRow(title: "Wake",
                        isOn: $preferences.wakeEnabled,
                        time: $preferences.wakeTime)
            scheduleRow(title: "Sleep",
                        isOn: $preferences.sleepEnabled,
                        time: $preferences.sleepTime)

            WeekdayPicker(selection: $preferences.scheduleDays)
                .disabled(!preferences.wakeEnabled && !preferences.sleepEnabled)
                .opacity(preferences.wakeEnabled || preferences.sleepEnabled ? 1 : 0.5)

            Text(PowerSchedule.description(
                wake: preferences.wakeEnabled ? preferences.wakeTime : nil,
                sleep: preferences.sleepEnabled ? preferences.sleepTime : nil,
                days: preferences.scheduleDays))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(applyButtonTitle) {
                    Task { await coordinator.applySchedule() }
                }
                .controlSize(.small)
                .disabled(schedule.isApplying
                          || !preferences.scheduleNeedsApplying
                          || !preferences.scheduleIsValid)
                .help("Asks for your administrator password: macOS only lets root set power events.")

                if schedule.isApplying {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                }
                Spacer()
                if !preferences.scheduleNeedsApplying
                    && (preferences.wakeEnabled || preferences.sleepEnabled) {
                    Label("In sync", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }

            if let error = schedule.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if preferences.scheduleNeedsApplying && preferences.scheduleIsValid {
                Text("Applying asks for your administrator password.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var applyButtonTitle: String {
        preferences.wakeEnabled || preferences.sleepEnabled ? "Apply schedule" : "Clear schedule"
    }

    private func scheduleRow(title: String, isOn: Binding<Bool>, time: Binding<TimeOfDay>) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: isOn) { Text(title) }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .frame(width: 78, alignment: .leading)

            DatePicker("", selection: TimeOfDay.binding(time), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!isOn.wrappedValue)
                .opacity(isOn.wrappedValue ? 1 : 0.5)

            Spacer()
        }
    }

    // MARK: - existing system events

    private var eventsSection: some View {
        DisclosureGroup(isExpanded: $showEvents) {
            VStack(alignment: .leading, spacing: 8) {
                eventList(title: "Repeating", events: schedule.report.repeating) {
                    Task { await coordinator.clearRepeatingSchedule() }
                }
                eventList(title: "One-time", events: schedule.report.oneTime) {
                    Task { await coordinator.clearOneTimeEvents() }
                }
                if schedule.report.isEmpty {
                    Text("Nothing scheduled.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Button("Refresh") { schedule.refresh() }
                    .controlSize(.small)
                    .buttonStyle(.link)
                    .font(.system(size: 10))
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 6) {
                SectionHeader(title: "System power events")
                Text("\(schedule.report.repeating.count + schedule.report.oneTime.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .disclosureGroupStyle(.automatic)
    }

    @ViewBuilder
    private func eventList(title: String, events: [PowerEvent], clear: @escaping () -> Void) -> some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear", action: clear)
                        .buttonStyle(.link)
                        .font(.system(size: 10))
                        .disabled(schedule.isApplying)
                }
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.summary)
                            .font(.system(size: 10, design: .monospaced))
                        if let owner = event.owner {
                            Text(owner)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    // MARK: - footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { loginItem.isEnabled },
                                 set: { loginItem.setEnabled($0) })) {
                Text("Launch at login")
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .disabled(!loginItem.isAvailable)
            .help(loginItem.isAvailable
                  ? "Start Caffeinum automatically when you log in."
                  : "Only available when running Caffeinum from an installed app bundle.")

            Toggle(isOn: $preferences.restoreOnLaunch) {
                Text("Restore keep awake on launch")
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            HStack(spacing: 8) {
                Toggle(isOn: $preferences.hotKeyEnabled) { Text("Global shortcut") }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                Spacer()
                HotKeyRecorder(combo: $preferences.hotKey, isEnabled: preferences.hotKeyEnabled)
            }

            if let error = loginItem.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit Caffeinum") { NSApplication.shared.terminate(nil) }
                    .controlSize(.small)
                    .keyboardShortcut("q")
            }
        }
    }
}
