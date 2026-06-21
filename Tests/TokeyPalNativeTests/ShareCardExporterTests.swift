import Foundation
import Testing
@testable import TokeyPalNative

@Test func shareCardExporterWritesPngFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let outputURL = directory.appendingPathComponent("TokeyPal-2026-06-18.png")
    let exporter = ShareCardExporter()
    let input = ShareCardInput(
        localDate: "2026-06-18",
        progressTokens: 12_500,
        todayUsage: [
            TodayAppUsage(appId: "claude", label: "Claude Code", tokens: 10_000),
            TodayAppUsage(appId: "codex", label: "codex", tokens: 2_500)
        ],
        sources: ["Claude Code", "codex"],
        characterId: "t-rex",
        stageLabel: "t-rex Stage 2",
        includeCharacter: false,
        characterImage: nil,
        approximate: false
    )

    let result = try exporter.export(input: input, outputURL: outputURL)
    let data = try Data(contentsOf: URL(fileURLWithPath: result.filePath))

    #expect(result.filePath == outputURL.path)
    #expect(Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
}
