import Foundation

/// Minimal wrapper for the read-only command line calls Caffeinum makes
/// (currently just `pmset -g sched`, which needs no privileges).
enum Shell {

    struct Result {
        var status: Int32
        var standardOutput: String
        var standardError: String
    }

    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            return Result(status: -1, standardOutput: "", standardError: error.localizedDescription)
        }

        // These outputs are a few lines at most, so reading before waiting cannot deadlock.
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Result(
            status: process.terminationStatus,
            standardOutput: String(data: outData, encoding: .utf8) ?? "",
            standardError: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
