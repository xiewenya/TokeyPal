import Foundation

public final class UsageService: Sendable {
    private let runner: CcusageRunner?
    private let cacheStore: UsageCacheStore?

    public init(runner: CcusageRunner? = nil, cacheStore: UsageCacheStore? = nil) {
        self.runner = runner
        self.cacheStore = cacheStore
    }

    public func currentStats(settings: TokeyPalSettings) throws -> UsageStats {
        let localDate = Self.localDateString()
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let loadedResponses = try runner?.loadUsageResponses(settings: settings) ?? []
        let responses = try cacheStore?.mergeWithCache(loadedResponses) ?? loadedResponses
        let freshSuccessfulResponses = responses.filter {
            !$0.isStale && $0.responseData != nil && $0.error == nil
        }
        if !freshSuccessfulResponses.isEmpty {
            try cacheStore?.write(freshSuccessfulResponses, updatedAt: generatedAt)
        }
        return try Self.buildUsageStats(
            localDate: localDate,
            generatedAt: generatedAt,
            responses: responses,
            settings: settings
        )
    }

    public func cachedStats(settings: TokeyPalSettings) throws -> UsageStats {
        let localDate = Self.localDateString()
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        return try Self.buildUsageStats(
            localDate: localDate,
            generatedAt: generatedAt,
            responses: cacheStore?.read() ?? [],
            settings: settings
        )
    }

    public static func buildUsageStats(
        localDate: String,
        generatedAt: String,
        responses: [LoadedUsageResponse],
        settings: TokeyPalSettings
    ) throws -> UsageStats {
        let responsesByApp = Dictionary(uniqueKeysWithValues: responses.map { ($0.appId, $0) })
        var appStats: [UsageAppStats] = []
        var globalRows: [String: NormalizedDailyRow] = [:]

        for app in orderedUsageApps() {
            let enabled = settings.usageApps[app.id] ?? false
            guard enabled else {
                appStats.append(emptyAppStats(appId: app.id, label: app.label, enabled: false, status: "disabled"))
                continue
            }

            guard let response = responsesByApp[app.id] else {
                appStats.append(emptyAppStats(appId: app.id, label: app.label, enabled: true, status: "no_data"))
                continue
            }

            if let error = response.error, response.responseData == nil {
                var empty = emptyAppStats(appId: app.id, label: response.label, enabled: true, status: "source_error")
                empty.error = error
                appStats.append(empty)
                continue
            }

            let rows = try normalizeDailyRows(response.responseData)
            var summarized = summarizeAppRows(appId: app.id, label: response.label, rows: rows, localDate: localDate)
            if let error = response.error {
                summarized.status = "source_error"
                summarized.error = error
            }
            appStats.append(summarized)
            for row in rows {
                add(row, to: &globalRows)
            }
        }

        let allRows = Array(globalRows.values).sorted { $0.localDate > $1.localDate }
        let totals = summarizeRows(allRows, localDate: localDate)
        let daily = allRows.map {
            UsageDailyTotal(localDate: $0.localDate, totalTokens: $0.totalTokens, totalCost: $0.totalCost)
        }

        return UsageStats(
            localDate: localDate,
            generatedAt: generatedAt,
            dataStatus: dataStatus(appStats: appStats, totals: totals),
            totals: totals,
            apps: appStats,
            daily: daily
        )
    }

    public static func snapshot(from stats: UsageStats, previousTotalTokens: Int? = nil) -> UsageSnapshot {
        UsageSnapshot(
            localDate: stats.localDate,
            progressTokens: stats.totals.todayTokens,
            exactTokens: stats.totals.todayTokens,
            estimatedTokens: 0,
            sources: stats.apps.filter { $0.enabled && $0.todayTokens > 0 }.map(\.label),
            dataStatus: stats.totals.todayTokens > 0 ? "ready" : "no_sources",
            accuracy: "exact",
            recentTokenDelta: max(0, stats.totals.todayTokens - (previousTotalTokens ?? stats.totals.todayTokens))
        )
    }

    public static func todayAppUsage(from stats: UsageStats) -> [TodayAppUsage] {
        stats.apps
            .filter { $0.enabled && $0.todayTokens > 0 }
            .map { TodayAppUsage(appId: $0.appId, label: $0.label, tokens: $0.todayTokens) }
    }

    public static func localDateString(date: Date = Date(), timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private func dataStatus(appStats: [UsageAppStats], totals: UsageTotals) -> String {
    if appStats.contains(where: { $0.enabled && $0.status == "source_error" }) {
        return "source_error"
    }
    return totals.totalTokens > 0 ? "ready" : "no_sources"
}

private func normalizeDailyRows(_ data: Data?) throws -> [NormalizedDailyRow] {
    guard let data else {
        return []
    }

    let decoded = try JSONSerialization.jsonObject(with: data)
    guard
        let root = decoded as? [String: Any],
        let rows = root["daily"] as? [Any]
    else {
        return []
    }

    return rows.compactMap { item in
        guard let row = item as? [String: Any] else {
            return nil
        }

        let localDate = row["period"] as? String ?? row["date"] as? String
        guard let localDate, !localDate.isEmpty else {
            return nil
        }

        let normalized = NormalizedDailyRow(
            localDate: localDate,
            totalTokens: positiveInt(row["totalTokens"]),
            inputTokens: positiveInt(row["inputTokens"]),
            outputTokens: positiveInt(row["outputTokens"]),
            cacheCreationTokens: positiveInt(row["cacheCreationTokens"]),
            cacheReadTokens: positiveInt(row["cacheReadTokens"] ?? row["cachedInputTokens"]),
            totalCost: positiveDouble(row["totalCost"] ?? row["costUSD"])
        )

        if normalized.totalTokens <= 0 && normalized.totalCost <= 0 {
            return nil
        }

        return normalized
    }
}

private func summarizeAppRows(appId: String, label: String, rows: [NormalizedDailyRow], localDate: String) -> UsageAppStats {
    guard !rows.isEmpty else {
        return emptyAppStats(appId: appId, label: label, enabled: true, status: "no_data")
    }

    let sorted = rows.sorted { $0.localDate > $1.localDate }
    let totals = summarizeRows(sorted, localDate: localDate)
    return UsageAppStats(
        appId: appId,
        label: label,
        enabled: true,
        status: "ready",
        totalTokens: totals.totalTokens,
        inputTokens: totals.inputTokens,
        outputTokens: totals.outputTokens,
        cacheCreationTokens: totals.cacheCreationTokens,
        cacheReadTokens: totals.cacheReadTokens,
        totalCost: totals.totalCost,
        todayTokens: totals.todayTokens,
        daysWithUsage: sorted.count,
        lastUsageDate: sorted.first?.localDate,
        error: nil
    )
}

private func summarizeRows(_ rows: [NormalizedDailyRow], localDate: String) -> UsageTotals {
    rows.reduce(UsageTotals.zero) { totals, row in
        UsageTotals(
            totalTokens: totals.totalTokens + row.totalTokens,
            inputTokens: totals.inputTokens + row.inputTokens,
            outputTokens: totals.outputTokens + row.outputTokens,
            cacheCreationTokens: totals.cacheCreationTokens + row.cacheCreationTokens,
            cacheReadTokens: totals.cacheReadTokens + row.cacheReadTokens,
            totalCost: totals.totalCost + row.totalCost,
            todayTokens: totals.todayTokens + (row.localDate == localDate ? row.totalTokens : 0),
            daysWithUsage: totals.daysWithUsage + 1
        )
    }
}

private func add(_ row: NormalizedDailyRow, to rows: inout [String: NormalizedDailyRow]) {
    let existing = rows[row.localDate] ?? NormalizedDailyRow(
        localDate: row.localDate,
        totalTokens: 0,
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationTokens: 0,
        cacheReadTokens: 0,
        totalCost: 0
    )

    rows[row.localDate] = NormalizedDailyRow(
        localDate: row.localDate,
        totalTokens: existing.totalTokens + row.totalTokens,
        inputTokens: existing.inputTokens + row.inputTokens,
        outputTokens: existing.outputTokens + row.outputTokens,
        cacheCreationTokens: existing.cacheCreationTokens + row.cacheCreationTokens,
        cacheReadTokens: existing.cacheReadTokens + row.cacheReadTokens,
        totalCost: existing.totalCost + row.totalCost
    )
}

private func emptyAppStats(appId: String, label: String, enabled: Bool, status: String) -> UsageAppStats {
    UsageAppStats(
        appId: appId,
        label: label,
        enabled: enabled,
        status: status,
        totalTokens: 0,
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationTokens: 0,
        cacheReadTokens: 0,
        totalCost: 0,
        todayTokens: 0,
        daysWithUsage: 0,
        lastUsageDate: nil,
        error: nil
    )
}

private func positiveInt(_ value: Any?) -> Int {
    if let int = value as? Int {
        return max(0, int)
    }
    if let double = value as? Double, double.isFinite {
        return max(0, Int(double.rounded()))
    }
    if let number = value as? NSNumber {
        return max(0, number.intValue)
    }
    return 0
}

private func positiveDouble(_ value: Any?) -> Double {
    if let double = value as? Double, double.isFinite {
        return max(0, double)
    }
    if let int = value as? Int {
        return Double(max(0, int))
    }
    if let number = value as? NSNumber {
        return max(0, number.doubleValue)
    }
    return 0
}
