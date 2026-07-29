import Foundation

enum PrivilegedShellError: Error, LocalizedError {
    /// The user dismissed the authentication dialog - not something to report as a failure.
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Cancelled."
        case .failed(let message): return message
        }
    }
}

/// Runs a command as root by handing it to AppleScript's
/// `do shell script … with administrator privileges`, which puts up the standard
/// macOS authentication dialog. Nothing is installed and nothing stays privileged.
///
/// Blocks until the user answers the dialog, so never call this on the main actor.
enum PrivilegedShell {

    @discardableResult
    static func run(_ command: String, prompt: String) throws -> String {
        let script = """
            do shell script \(quoted(command)) \
            with prompt \(quoted(prompt)) \
            with administrator privileges
            """

        let result = Shell.run("/usr/bin/osascript", ["-e", script])
        guard result.status == 0 else {
            let message = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("-128") || message.localizedCaseInsensitiveContains("user canceled") {
                throw PrivilegedShellError.cancelled
            }
            throw PrivilegedShellError.failed(message.isEmpty ? "Command failed." : message)
        }
        return result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Escapes a Swift string into an AppleScript string literal.
    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
