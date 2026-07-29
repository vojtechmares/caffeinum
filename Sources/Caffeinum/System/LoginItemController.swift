import Combine
import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp`, which only works for a real, signed app bundle -
/// running the raw executable from `.build` will report `isAvailable == false`.
@MainActor
final class LoginItemController: ObservableObject {

    @Published private(set) var isEnabled = false
    @Published var lastError: String?

    /// False when Caffeinum is not running from an app bundle, in which case the
    /// UI explains why the toggle is disabled instead of failing on click.
    let isAvailable: Bool

    init() {
        isAvailable = Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
        refresh()
    }

    func refresh() {
        guard isAvailable else {
            isEnabled = false
            return
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}
