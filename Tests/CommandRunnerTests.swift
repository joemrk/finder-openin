import XCTest

final class CommandRunnerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-open-in-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private let commands = [
        Command(title: "Touch", cmd: ["/usr/bin/touch", "{path}/marker"]),
        Command(title: "NoPath", cmd: ["/usr/bin/true"]),
    ]

    private func exitCode(of plan: LaunchPlan, timeout: TimeInterval = 20) -> Int32? {
        let done = expectation(description: "exit")
        let box = ExitBox()
        XCTAssertTrue(CommandRunner.launch(plan) { code, _ in
            box.set(code)
            done.fulfill()
        })
        wait(for: [done], timeout: timeout)
        return box.value
    }

    private func notices(for request: RunRequest, config: String?, expecting count: Int) throws -> [FailureNotice] {
        var configURL: URL?
        if let config {
            let url = dir.appendingPathComponent("commands.json")
            try Data(config.utf8).write(to: url)
            configURL = url
        }
        let done = expectation(description: "notice")
        done.expectedFulfillmentCount = count
        let box = NoticeBox()
        CommandRunner.run(request, configURL: configURL) { notice in
            box.append(notice)
            done.fulfill()
        }
        wait(for: [done], timeout: 20)
        return box.values
    }

    // MARK: - Failure notices

    func testNoNoticeOnSuccess() {
        XCTAssertNil(CommandRunner.notice(title: "IDE", executable: "ide", exitCode: 0, stderr: "warning"))
    }

    func testNoticeForMissingCommand() {
        XCTAssertEqual(
            CommandRunner.notice(title: "Zed", executable: "zed", exitCode: 127, stderr: "zsh:1: command not found: zed"),
            FailureNotice(title: "Open in Zed failed",
                          body: "Command not found: zed. Check that it is installed and on your shell PATH."))
    }

    func testNoticeForNonExecutableCommand() {
        XCTAssertEqual(
            CommandRunner.notice(title: "Tool", executable: "/tmp/tool", exitCode: 126, stderr: "zsh: permission denied: /tmp/tool"),
            FailureNotice(title: "Open in Tool failed",
                          body: "Command is not executable: /tmp/tool."))
    }

    func testNoticeForOtherExitCodeUsesLastStderrLine() {
        XCTAssertEqual(
            CommandRunner.notice(title: "Antigravity", executable: "agy", exitCode: 2,
                                 stderr: "Error: unexpected argument \"/tmp/x\".\nPrompts are read only from stdin.\n\n"),
            FailureNotice(title: "Open in Antigravity failed",
                          body: "agy exited with code 2: Prompts are read only from stdin."))
    }

    func testNoticeForOtherExitCodeWithoutStderr() {
        XCTAssertEqual(
            CommandRunner.notice(title: "X", executable: "x", exitCode: 1, stderr: "  \n"),
            FailureNotice(title: "Open in X failed", body: "x exited with code 1."))
    }

    func testNoticeTruncatesLongStderrLine() throws {
        let notice = try XCTUnwrap(CommandRunner.notice(title: "X", executable: "x", exitCode: 1,
                                                        stderr: String(repeating: "e", count: 5000)))
        XCTAssertLessThanOrEqual(notice.body.count, 260)
        XCTAssertTrue(notice.body.hasSuffix("…"))
    }

    func testNoticesForRejectedRequests() {
        XCTAssertEqual(CommandRunner.notice(for: .unknownCommand("Gone")),
                       FailureNotice(title: "Open in Gone failed",
                                     body: "This command is no longer in commands.json."))
        XCTAssertEqual(CommandRunner.notice(for: .missingPath("/tmp/gone")),
                       FailureNotice(title: "Open in… failed", body: "Path does not exist: /tmp/gone"))
        XCTAssertEqual(CommandRunner.notice(for: .relativePath("a/b")),
                       FailureNotice(title: "Open in… failed", body: "Path is not absolute: a/b"))
    }

    func testLaunchReportsStderr() {
        let plan = LaunchPlan(title: "err", argv: ["/bin/sh", "-c", "echo boom >&2; exit 3"], workingDirectory: dir)
        let done = expectation(description: "exit")
        let box = NoticeBox()
        CommandRunner.launch(plan) { code, stderr in
            box.append(FailureNotice(title: "\(code)", body: stderr))
            done.fulfill()
        }
        wait(for: [done], timeout: 20)
        XCTAssertEqual(box.values.first?.title, "3")
        XCTAssertEqual(box.values.first?.body.trimmingCharacters(in: .whitespacesAndNewlines), "boom")
    }

    func testRunNotifiesWhenCommandIsMissingFromPath() throws {
        let binary = "finder-open-in-no-such-binary"
        let result = try notices(for: RunRequest(id: "Broken", path: dir.path),
                                 config: #"[{"title":"Broken","cmd":["\#(binary)","{path}"]}]"#, expecting: 1)
        XCTAssertEqual(result, [FailureNotice(
            title: "Open in Broken failed",
            body: "Command not found: \(binary). Check that it is installed and on your shell PATH.")])
    }

    func testRunNotifiesOnUnknownCommand() throws {
        let result = try notices(for: RunRequest(id: "Gone", path: dir.path), config: "[]", expecting: 1)
        XCTAssertEqual(result, [CommandRunner.notice(for: .unknownCommand("Gone"))])
    }

    func testRunNotifiesOnInvalidConfig() throws {
        let result = try notices(for: RunRequest(id: "A", path: dir.path), config: "not json", expecting: 1)
        XCTAssertEqual(result, [FailureNotice(title: "Open in A failed",
                                              body: "commands.json is missing or invalid. See the log for details.")])
    }

    func testRunDoesNotNotifyOnSuccess() throws {
        let url = dir.appendingPathComponent("commands.json")
        try Data(#"[{"title":"Touch","cmd":["/usr/bin/touch","{path}/ok"]}]"#.utf8).write(to: url)
        let noNotice = expectation(description: "no notice")
        noNotice.isInverted = true
        CommandRunner.run(RunRequest(id: "Touch", path: dir.path), configURL: url) { _ in noNotice.fulfill() }
        wait(for: [noNotice], timeout: 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("ok").path))
    }

    func testShellArgumentsAreConstantScriptPlusArgv() {
        XCTAssertEqual(CommandRunner.shellArguments(["agy", "/tmp/a b"]),
                       ["-lc", "exec \"$@\"", "zsh", "agy", "/tmp/a b"])
    }

    func testPlanForDirectory() throws {
        let plan = try CommandRunner.plan(RunRequest(id: "Touch", path: dir.path), commands: commands).get()
        XCTAssertEqual(plan.title, "Touch")
        XCTAssertEqual(plan.argv, ["/usr/bin/touch", dir.path + "/marker"])
        // Compare paths: the URLs may differ by a trailing slash.
        XCTAssertEqual(plan.workingDirectory.path, dir.path)
    }

    func testPlanForFileUsesParentAsWorkingDirectory() throws {
        let file = dir.appendingPathComponent("note.txt")
        try Data().write(to: file)
        let plan = try CommandRunner.plan(RunRequest(id: "NoPath", path: file.path), commands: commands).get()
        XCTAssertEqual(plan.workingDirectory.path, dir.path)
        XCTAssertEqual(plan.argv, ["/usr/bin/true"])
    }

    func testPlanRejectsUnknownCommand() {
        XCTAssertEqual(CommandRunner.plan(RunRequest(id: "Gone", path: dir.path), commands: commands),
                       .failure(.unknownCommand("Gone")))
    }

    func testPlanRejectsRelativePath() {
        XCTAssertEqual(CommandRunner.plan(RunRequest(id: "Touch", path: "relative/dir"), commands: commands),
                       .failure(.relativePath("relative/dir")))
    }

    func testPlanRejectsMissingPath() {
        let gone = dir.appendingPathComponent("deleted").path
        XCTAssertEqual(CommandRunner.plan(RunRequest(id: "Touch", path: gone), commands: commands),
                       .failure(.missingPath(gone)))
    }

    func testLaunchPassesNastyPathAsSingleArgument() throws {
        let nasty = dir.appendingPathComponent("a b's \"c\" $HOME `id` ;x& тест")
        try FileManager.default.createDirectory(at: nasty, withIntermediateDirectories: true)
        let plan = try CommandRunner.plan(RunRequest(id: "Touch", path: nasty.path), commands: commands).get()
        XCTAssertEqual(exitCode(of: plan), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nasty.appendingPathComponent("marker").path))
    }

    func testLaunchUsesWorkingDirectory() throws {
        let plan = LaunchPlan(title: "cwd", argv: ["/usr/bin/touch", "relative-marker"], workingDirectory: dir)
        XCTAssertEqual(exitCode(of: plan), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("relative-marker").path))
    }

    func testLargeOutputDoesNotHang() {
        let plan = LaunchPlan(title: "big",
                              argv: ["/bin/sh", "-c", "head -c 400000 /dev/zero | tr '\\0' 'x'; echo err >&2"],
                              workingDirectory: dir)
        XCTAssertEqual(exitCode(of: plan), 0)
    }

    func testMissingBinaryExits127() {
        let plan = LaunchPlan(title: "missing",
                              argv: ["finder-open-in-no-such-binary-\(UUID().uuidString)"],
                              workingDirectory: dir)
        XCTAssertEqual(exitCode(of: plan), 127)
    }

    func testNonZeroExitIsReported() {
        let plan = LaunchPlan(title: "false", argv: ["/usr/bin/false"], workingDirectory: dir)
        XCTAssertEqual(exitCode(of: plan), 1)
    }
}

private final class ExitBox: @unchecked Sendable {
    private let lock = NSLock()
    private var code: Int32?

    func set(_ value: Int32) {
        lock.lock(); defer { lock.unlock() }
        code = value
    }

    var value: Int32? {
        lock.lock(); defer { lock.unlock() }
        return code
    }
}

private final class NoticeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var notices: [FailureNotice] = []

    func append(_ notice: FailureNotice) {
        lock.lock(); defer { lock.unlock() }
        notices.append(notice)
    }

    var values: [FailureNotice] {
        lock.lock(); defer { lock.unlock() }
        return notices
    }
}
