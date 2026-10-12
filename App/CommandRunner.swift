import Foundation
import os

struct LaunchPlan: Equatable {
    let title: String
    let argv: [String]
    let workingDirectory: URL
}

enum RunError: Error, Equatable {
    case unknownCommand(String)
    case relativePath(String)
    case missingPath(String)
}

/// Text of the window reporting a failed launch.
struct FailureNotice: Equatable {
    let title: String
    let body: String
}

enum CommandRunner {
    static let shell = URL(fileURLWithPath: "/bin/zsh")

    /// The -c script is a constant; argv is passed as positional arguments.
    static func shellArguments(_ argv: [String]) -> [String] {
        ["-lc", "exec \"$@\"", "zsh"] + argv
    }

    static func plan(_ request: RunRequest, commands: [Command]) -> Result<LaunchPlan, RunError> {
        guard let command = commands.first(where: { $0.title == request.id }) else {
            return .failure(.unknownCommand(request.id))
        }
        guard request.path.hasPrefix("/") else {
            return .failure(.relativePath(request.path))
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: request.path, isDirectory: &isDirectory) else {
            return .failure(.missingPath(request.path))
        }
        let target = URL(fileURLWithPath: request.path)
        return .success(LaunchPlan(
            title: command.title,
            argv: CommandTemplate.expand(command.cmd, path: request.path),
            workingDirectory: isDirectory.boolValue ? target : target.deletingLastPathComponent()
        ))
    }

    // MARK: - Notices

    /// nil on success. 127 and 126 are the zsh codes for "not found" and "not executable".
    static func notice(title: String, executable: String, exitCode: Int32, stderr: String) -> FailureNotice? {
        let body: String
        switch exitCode {
        case 0:
            return nil
        case 127:
            body = "Command not found: \(executable). Check that it is installed and on your shell PATH."
        case 126:
            body = "Command is not executable: \(executable)."
        default:
            let lastLine = stderr
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last { !$0.isEmpty }
            if let lastLine {
                body = truncated("\(executable) exited with code \(exitCode): \(lastLine)")
            } else {
                body = "\(executable) exited with code \(exitCode)."
            }
        }
        return FailureNotice(title: "Open in \(title) failed", body: body)
    }

    static func notice(for error: RunError) -> FailureNotice {
        switch error {
        case .unknownCommand(let id):
            return FailureNotice(title: "Open in \(id) failed",
                                 body: "This command is no longer in commands.json.")
        case .missingPath(let path):
            return FailureNotice(title: "Open in… failed", body: truncated("Path does not exist: \(path)"))
        case .relativePath(let path):
            return FailureNotice(title: "Open in… failed", body: truncated("Path is not absolute: \(path)"))
        }
    }

    private static func truncated(_ text: String, limit: Int = 260) -> String {
        text.count <= limit ? text : text.prefix(limit - 1) + "…"
    }

    // MARK: - Launch

    /// `onExit` receives the exit code and the tail of stderr.
    @discardableResult
    static func launch(_ plan: LaunchPlan, onExit: (@Sendable (Int32, String) -> Void)? = nil) -> Bool {
        let title = plan.title
        let process = Process()
        process.executableURL = shell
        process.arguments = shellArguments(plan.argv)
        process.currentDirectoryURL = plan.workingDirectory
        process.standardInput = FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        let stderrTail = TailBuffer()
        process.standardOutput = stdout
        process.standardError = stderr
        forward(stdout, to: .debug, title: title, tail: nil)
        forward(stderr, to: .error, title: title, tail: stderrTail)

        process.terminationHandler = { finished in
            let code = finished.terminationStatus
            if code == 0 {
                Log.runner.info("[\(title, privacy: .public)] exited 0")
            } else {
                Log.runner.error("[\(title, privacy: .public)] exited \(code)")
            }
            guard let onExit else { return }
            // The pipe is not read to EOF: a child process of the IDE may keep it open.
            // A short pause lets the stderr handler pick up what is already written.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                onExit(code, stderrTail.text)
            }
        }

        Log.runner.info("[\(title, privacy: .public)] launching \(plan.argv, privacy: .public) in \(plan.workingDirectory.path, privacy: .public)")
        do {
            try process.run()
            return true
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            Log.runner.error("[\(title, privacy: .public)] cannot start zsh: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// `notify` is called for every failure the user should see.
    static func run(_ request: RunRequest, configURL: URL?,
                    notify: @escaping @Sendable (FailureNotice) -> Void = { _ in }) {
        let configFailure = FailureNotice(title: "Open in \(request.id) failed",
                                          body: "commands.json is missing or invalid. See the log for details.")
        guard let configURL else {
            Log.runner.error("no app group container; cannot run \(request.id, privacy: .public)")
            notify(configFailure)
            return
        }
        switch ConfigLoader.load(from: configURL) {
        case .failure(let error):
            Log.runner.error("config error: \(String(describing: error), privacy: .public)")
            notify(configFailure)
        case .success(let commands):
            switch plan(request, commands: commands) {
            case .failure(let error):
                Log.runner.error("rejected request: \(String(describing: error), privacy: .public)")
                notify(notice(for: error))
            case .success(let plan):
                let executable = plan.argv.first ?? ""
                let started = launch(plan) { code, stderr in
                    if let failure = notice(title: plan.title, executable: executable,
                                            exitCode: code, stderr: stderr) {
                        notify(failure)
                    }
                }
                if !started {
                    notify(FailureNotice(title: "Open in \(plan.title) failed", body: "Could not start /bin/zsh."))
                }
            }
        }
    }

    /// Reads the pipe in chunks so that large output does not block the child process.
    private static func forward(_ pipe: Pipe, to level: OSLogType, title: String, tail: TailBuffer?) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            tail?.append(text)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            Log.runner.log(level: level, "[\(title, privacy: .public)] \(trimmed, privacy: .public)")
        }
    }
}

/// The last characters of a stream; safe to write to from a pipe handler.
private final class TailBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let limit = 4000
    private var storage = ""

    func append(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        storage += text
        if storage.count > limit { storage = String(storage.suffix(limit)) }
    }

    var text: String {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}
