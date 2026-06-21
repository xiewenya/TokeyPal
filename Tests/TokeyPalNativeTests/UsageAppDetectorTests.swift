import Testing
@testable import TokeyPalNative

@Test func defaultsCoverKnownAppsAndFallback() {
    #expect(defaultUsageDirectories(for: "claude") == ["~/.claude/projects"])
    #expect(defaultUsageDirectories(for: "openclaw").count >= 2)
    #expect(defaultUsageDirectories(for: "totally-unknown") == ["~/.totally-unknown"])
}

@Test func detectsWhenADirectoryExists() {
    let present = "/tmp/exists"
    let detector = UsageAppDetector(fileExistsAsDirectory: { $0 == present })
    let r = detector.detect(appId: "claude", customDirectories: ["/tmp/missing", present])
    #expect(r.status == "detected")
    #expect(r.matchedPath == present)
    #expect(r.checkedDirectories.contains(present))
}

@Test func missingWhenNoDirectoryExists() {
    let detector = UsageAppDetector(fileExistsAsDirectory: { _ in false })
    let r = detector.detect(appId: "codex", customDirectories: [])
    #expect(r.status == "missing")
    #expect(r.matchedPath == nil)
    #expect(r.checkedDirectories == defaultUsageDirectories(for: "codex"))
    #expect(!r.message.isEmpty)
}
