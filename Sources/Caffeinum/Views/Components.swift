import AppKit
import SwiftUI

/// Small uppercase heading that separates the panel's sections.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(.tertiary)
    }
}

/// A checkbox with the matching `caffeinate` flag shown alongside it.
struct FlagToggle: View {
    let title: String
    let flag: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 6) {
                Text(title)
                Text(flag)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

/// Seven letter buttons for choosing which days a schedule repeats on.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(day.initial)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.12))
                        )
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .help(day.name)
            }
        }
    }
}

/// Click to record, then press the combination you want.
struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo
    var isEnabled: Bool

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Press keys…" : combo.displayString)
                .font(.system(size: 11, weight: .medium))
                .frame(minWidth: 62)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isRecording ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape abandons the recording
                stopRecording()
                return nil
            }
            let candidate = HotKeyCombo(event: event)
            guard candidate.isValid else { return nil }
            combo = candidate
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}

extension TimeOfDay {
    /// Bridges the hour/minute pair to the `Date` a `DatePicker` binds to.
    static func binding(_ source: Binding<TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { source.wrappedValue.date() },
            set: { source.wrappedValue = TimeOfDay(date: $0) }
        )
    }
}
