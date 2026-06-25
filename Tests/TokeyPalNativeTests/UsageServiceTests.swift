import Foundation
import Testing
@testable import TokeyPalNative

@Test func usageServiceSummarizesCcusageDailyRows() throws {
    let response = """
    {
      "daily": [
        {
          "date": "2026-06-17",
          "totalTokens": 100,
          "inputTokens": 30,
          "outputTokens": 40,
          "cacheCreationTokens": 10,
          "cacheReadTokens": 20,
          "totalCost": 1.25
        },
        {
          "period": "2026-06-18",
          "totalTokens": 250,
          "inputTokens": 100,
          "outputTokens": 90,
          "cacheCreationTokens": 30,
          "cachedInputTokens": 30,
          "costUSD": 2.5
        }
      ]
    }
    """.data(using: .utf8)!

    let stats = try UsageService.buildUsageStats(
        localDate: "2026-06-18",
        generatedAt: "2026-06-18T00:00:00Z",
        responses: [LoadedUsageResponse(appId: "claude", label: "Claude Code", responseData: response)],
        settings: TokeyPalSettings.default
    )

    #expect(stats.dataStatus == "ready")
    #expect(stats.totals.totalTokens == 350)
    #expect(stats.totals.inputTokens == 130)
    #expect(stats.totals.outputTokens == 130)
    #expect(stats.totals.cacheCreationTokens == 40)
    #expect(stats.totals.cacheReadTokens == 50)
    #expect(stats.totals.totalCost == 3.75)
    #expect(stats.totals.todayTokens == 250)
    #expect(stats.daily.first?.localDate == "2026-06-18")
    #expect(stats.apps.first(where: { $0.appId == "claude" })?.todayTokens == 250)
}

@Test func usageServiceReportsSourceErrorWhileUsingStaleCachedResponse() throws {
    let response = """
    {
      "daily": [
        {
          "date": "2026-06-18",
          "totalTokens": 900,
          "inputTokens": 300,
          "outputTokens": 400,
          "cacheCreationTokens": 100,
          "cacheReadTokens": 100,
          "totalCost": 9
        }
      ]
    }
    """.data(using: .utf8)!

    let stats = try UsageService.buildUsageStats(
        localDate: "2026-06-18",
        generatedAt: "2026-06-18T00:00:00Z",
        responses: [
            LoadedUsageResponse(
                appId: "claude",
                label: "Claude Code",
                responseData: response,
                error: "ccusage timed out",
                isStale: true
            )
        ],
        settings: TokeyPalSettings.default
    )

    let claude = try #require(stats.apps.first(where: { $0.appId == "claude" }))
    #expect(stats.dataStatus == "source_error")
    #expect(stats.totals.todayTokens == 900)
    #expect(claude.status == "source_error")
    #expect(claude.todayTokens == 900)
    #expect(claude.error == "ccusage timed out")
}

@Test func usageCacheStoreReturnsCachedResponsesWhenFreshLoadFails() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = UsageCacheStore(cacheURL: directory.appendingPathComponent("usage-cache.json"))
    let response = #"{"daily":[{"date":"2026-06-18","totalTokens":42}]}"#.data(using: .utf8)!

    try store.write([
        LoadedUsageResponse(appId: "claude", label: "Claude Code", responseData: response)
    ], updatedAt: "2026-06-18T00:00:00Z")

    let cached = try store.mergeWithCache([
        LoadedUsageResponse(appId: "claude", label: "Claude Code", error: "ccusage failed")
    ])

    #expect(cached.count == 1)
    #expect(cached[0].responseData == response)
    #expect(cached[0].error == "ccusage failed")
    #expect(cached[0].isStale == true)
}

@Test func usageCacheStoreIgnoresLegacyElectronCacheFormat() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cacheURL = directory.appendingPathComponent("usage-cache.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("""
    {
      "schemaVersion": 1,
      "apps": {
        "claude": {
          "history": {
            "response": {
              "daily": [
                { "date": "2026-06-18", "totalTokens": 42 }
              ]
            }
          }
        }
      }
    }
    """.utf8).write(to: cacheURL)

    let store = UsageCacheStore(cacheURL: cacheURL)

    #expect(try store.read().isEmpty)
    #expect(try store.mergeWithCache([
        LoadedUsageResponse(appId: "claude", label: "Claude Code", error: "fresh load failed")
    ])[0].error == "fresh load failed")
}

@Test func usageServiceStillBuildsStatsWhenExistingCacheUsesLegacyFormat() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cacheURL = directory.appendingPathComponent("usage-cache.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("""
    {
      "schemaVersion": 1,
      "apps": {
        "claude": {
          "history": {
            "response": { "daily": [] }
          }
        }
      }
    }
    """.utf8).write(to: cacheURL)
    let service = UsageService(
        runner: nil,
        cacheStore: UsageCacheStore(cacheURL: cacheURL)
    )

    let stats = try service.currentStats(settings: .default)

    #expect(stats.apps.contains(where: { $0.appId == "claude" }))
    #expect(stats.dataStatus == "no_sources")
}

@Test func usageServiceKeepsExistingCacheWhenFreshLoadOnlyReturnsErrors() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cacheURL = directory.appendingPathComponent("usage-cache.json")
    let store = UsageCacheStore(cacheURL: cacheURL)
    let cachedResponse = #"{"daily":[{"date":"2026-06-18","totalTokens":42}]}"#.data(using: .utf8)!
    try store.write([
        LoadedUsageResponse(appId: "claude", label: "Claude Code", responseData: cachedResponse)
    ], updatedAt: "2026-06-18T00:00:00Z")
    let before = try Data(contentsOf: cacheURL)

    let service = UsageService(
        runner: CcusageRunner(executableURL: directory.appendingPathComponent("missing-ccusage")),
        cacheStore: store
    )

    _ = try service.currentStats(settings: .default)

    #expect(try Data(contentsOf: cacheURL) == before)
    #expect(try store.read().first?.responseData == cachedResponse)
}

@Test func usageServiceCachedStatsAvoidsRerunningCcusage() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cacheURL = directory.appendingPathComponent("usage-cache.json")
    let service = UsageService(
        runner: CcusageRunner(executableURL: directory.appendingPathComponent("missing-ccusage")),
        cacheStore: UsageCacheStore(cacheURL: cacheURL)
    )

    let stats = try service.cachedStats(settings: .default)

    #expect(stats.dataStatus == "no_sources")
}
