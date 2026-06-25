import Foundation
import Testing
@testable import TokeyPalNative

@Test func ccusageRunnerBuildsAgentArgsWithTimezoneAndCustomPath() {
    let runner = CcusageRunner(
        executableURL: URL(fileURLWithPath: "/bin/echo"),
        timeZoneIdentifier: "Asia/Shanghai"
    )

    let args = runner.buildArgs(
        app: UsageAppConfig(id: "openclaw", label: "openclaw", ccusageCommand: "openclaw", visibleByDefault: true),
        customDirectories: ["/tmp/a", "/tmp/b"]
    )

    #expect(args == [
        "openclaw",
        "daily",
        "--json",
        "--offline",
        "--timezone",
        "Asia/Shanghai",
        "--open-claw-path",
        "/tmp/a,/tmp/b"
    ])
}

@Test func ccusageRunnerRejectsOutputAboveLimit() throws {
    let runner = CcusageRunner(
        executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
        maxOutputBytes: 4
    )

    #expect(throws: CcusageRunnerError.outputTooLarge(limit: 4)) {
        _ = try runner.run(
            app: UsageAppConfig(id: "claude", label: "Claude Code", ccusageCommand: "abcdef", visibleByDefault: true),
            customDirectories: []
        )
    }
}

@Test func ccusageRunnerTimesOutLongRunningProcess() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let scriptURL = directory.appendingPathComponent("sleeping-ccusage")
    try Data("#!/bin/sh\nsleep 2\n".utf8).write(to: scriptURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let runner = CcusageRunner(
        executableURL: scriptURL,
        timeoutSeconds: 0.1
    )

    #expect(throws: CcusageRunnerError.timedOut(timeoutSeconds: 0.1)) {
        _ = try runner.run(
            app: UsageAppConfig(id: "claude", label: "Claude Code", ccusageCommand: "2", visibleByDefault: true),
            customDirectories: []
        )
    }
}

@Test func ccusageRunnerReadsLargeOutputWithoutBlockingProcessExit() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let scriptURL = directory.appendingPathComponent("chatty-ccusage")
    try Data("""
    #!/bin/sh
    /usr/bin/perl -e 'print "x" x (2 * 1024 * 1024)'
    """.utf8).write(to: scriptURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let runner = CcusageRunner(
        executableURL: scriptURL,
        timeoutSeconds: 1,
        maxOutputBytes: 3 * 1024 * 1024
    )

    let output = try runner.run(
        app: UsageAppConfig(id: "codex", label: "codex", ccusageCommand: "codex", visibleByDefault: true),
        customDirectories: []
    )

    #expect(output.count == 2 * 1024 * 1024)
}
