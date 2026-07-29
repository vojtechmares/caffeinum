import AppKit
import SwiftUI

@main
struct CaffeinumApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(coordinator: coordinator)
        } label: {
            MenuBarLabel(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        if let countdown = coordinator.menuBarCountdown {
            HStack(spacing: 3) {
                Image(systemName: coordinator.menuBarSymbol)
                Text(countdown).font(.system(size: 11, weight: .medium).monospacedDigit())
            }
        } else {
            Image(systemName: coordinator.menuBarSymbol)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppCoordinator.shared.applicationWillTerminate()
    }
}
