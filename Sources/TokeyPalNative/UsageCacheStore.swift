import Foundation

public struct UsageCacheStore: Sendable {
    public let cacheURL: URL

    public init(cacheURL: URL) {
        self.cacheURL = cacheURL
    }

    public func read() throws -> [LoadedUsageResponse] {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return []
        }

        let data = try Data(contentsOf: cacheURL)
        guard let cache = try? JSONDecoder().decode(UsageCache.self, from: data) else {
            return []
        }
        guard cache.schemaVersion == 1 else {
            return []
        }

        return cache.apps.compactMap { item in
            guard let responseData = Data(base64Encoded: item.responseBase64) else {
                return nil
            }
            return LoadedUsageResponse(appId: item.appId, label: item.label, responseData: responseData)
        }
    }

    public func write(_ responses: [LoadedUsageResponse], updatedAt: String) throws {
        let apps = responses.compactMap { response -> UsageCacheApp? in
            guard let responseData = response.responseData, response.error == nil else {
                return nil
            }
            return UsageCacheApp(
                appId: response.appId,
                label: response.label,
                importedAt: updatedAt,
                responseBase64: responseData.base64EncodedString()
            )
        }

        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(UsageCache(schemaVersion: 1, updatedAt: updatedAt, apps: apps))
        try data.write(to: cacheURL, options: .atomic)
    }

    public func mergeWithCache(_ responses: [LoadedUsageResponse]) throws -> [LoadedUsageResponse] {
        let cachedByApp = Dictionary(uniqueKeysWithValues: try read().map { ($0.appId, $0) })
        return responses.map { response in
            guard response.responseData == nil, let cached = cachedByApp[response.appId] else {
                return response
            }
            return LoadedUsageResponse(
                appId: response.appId,
                label: response.label,
                responseData: cached.responseData ?? Data(),
                error: response.error,
                isStale: true
            )
        }
    }
}

private struct UsageCache: Codable {
    var schemaVersion: Int
    var updatedAt: String
    var apps: [UsageCacheApp]
}

private struct UsageCacheApp: Codable {
    var appId: String
    var label: String
    var importedAt: String
    var responseBase64: String
}
