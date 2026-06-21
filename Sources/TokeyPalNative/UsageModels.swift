import Foundation

public struct UsageDailyTotal: Codable, Equatable, Sendable {
    public var localDate: String
    public var totalTokens: Int
    public var totalCost: Double
}

public struct UsageTotals: Codable, Equatable, Sendable {
    public var totalTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheCreationTokens: Int
    public var cacheReadTokens: Int
    public var totalCost: Double
    public var todayTokens: Int
    public var daysWithUsage: Int

    public static let zero = UsageTotals(
        totalTokens: 0,
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationTokens: 0,
        cacheReadTokens: 0,
        totalCost: 0,
        todayTokens: 0,
        daysWithUsage: 0
    )
}

public struct UsageAppStats: Codable, Equatable, Sendable {
    public var appId: String
    public var label: String
    public var enabled: Bool
    public var status: String
    public var totalTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheCreationTokens: Int
    public var cacheReadTokens: Int
    public var totalCost: Double
    public var todayTokens: Int
    public var daysWithUsage: Int
    public var lastUsageDate: String?
    public var error: String?
}

public struct UsageStats: Codable, Equatable, Sendable {
    public var localDate: String
    public var generatedAt: String
    public var dataStatus: String
    public var totals: UsageTotals
    public var apps: [UsageAppStats]
    public var daily: [UsageDailyTotal]
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var localDate: String
    public var progressTokens: Int
    public var exactTokens: Int
    public var estimatedTokens: Int
    public var sources: [String]
    public var dataStatus: String
    public var accuracy: String
    public var recentTokenDelta: Int

    public init(
        localDate: String,
        progressTokens: Int,
        exactTokens: Int,
        estimatedTokens: Int,
        sources: [String],
        dataStatus: String,
        accuracy: String,
        recentTokenDelta: Int
    ) {
        self.localDate = localDate
        self.progressTokens = progressTokens
        self.exactTokens = exactTokens
        self.estimatedTokens = estimatedTokens
        self.sources = sources
        self.dataStatus = dataStatus
        self.accuracy = accuracy
        self.recentTokenDelta = recentTokenDelta
    }
}

public struct TodayAppUsage: Codable, Equatable, Sendable {
    public var appId: String
    public var label: String
    public var tokens: Int
}

public struct ShareCardInput: Codable, Equatable, Sendable {
    public var localDate: String
    public var progressTokens: Int
    public var todayUsage: [TodayAppUsage]
    public var sources: [String]
    public var characterId: String
    public var stageLabel: String
    public var includeCharacter: Bool
    public var characterImage: String?
    public var approximate: Bool

    public init(
        localDate: String,
        progressTokens: Int,
        todayUsage: [TodayAppUsage],
        sources: [String],
        characterId: String,
        stageLabel: String,
        includeCharacter: Bool,
        characterImage: String?,
        approximate: Bool
    ) {
        self.localDate = localDate
        self.progressTokens = progressTokens
        self.todayUsage = todayUsage
        self.sources = sources
        self.characterId = characterId
        self.stageLabel = stageLabel
        self.includeCharacter = includeCharacter
        self.characterImage = characterImage
        self.approximate = approximate
    }
}

public struct ShareExportOptions: Codable, Equatable, Sendable {
    public var includeCharacter: Bool?
}

public struct UsageAppDetectionResult: Codable, Equatable, Sendable {
    public var appId: String
    public var status: String
    public var checkedDirectories: [String]
    public var matchedPath: String?
    public var message: String

    public init(appId: String, status: String, checkedDirectories: [String], matchedPath: String?, message: String) {
        self.appId = appId
        self.status = status
        self.checkedDirectories = checkedDirectories
        self.matchedPath = matchedPath
        self.message = message
    }
}

public struct LoadedUsageResponse: Sendable {
    public var appId: String
    public var label: String
    public var responseData: Data?
    public var error: String?
    public var isStale: Bool

    public init(appId: String, label: String, responseData: Data, error: String? = nil, isStale: Bool = false) {
        self.appId = appId
        self.label = label
        self.responseData = responseData
        self.error = error
        self.isStale = isStale
    }

    public init(appId: String, label: String, error: String, isStale: Bool = false) {
        self.appId = appId
        self.label = label
        self.responseData = nil
        self.error = error
        self.isStale = isStale
    }
}

struct NormalizedDailyRow: Equatable {
    var localDate: String
    var totalTokens: Int
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var totalCost: Double
}
