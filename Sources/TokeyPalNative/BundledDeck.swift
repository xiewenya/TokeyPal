import Foundation

// MARK: - 内置卡组（Bundled_Deck）本地可用性与卡组基路径解析
//
// 映射 Requirement 6.1 / 6.3 与设计文档 "内置卡组（Bundled_Deck）" 一节。
//
// 设计要点（与 design.md 一致）：
// - Native_App 随应用分发免费 Bundled_Deck，资源与数据位于 `Resources/data/{id}/`，
//   安装后即本地可用、无需任何网络下载（Req 6.1）。
// - 运行时按"是否 bundled"解析卡组资源基路径：
//   * bundled 卡组解析到 `Resources/data/{id}`（复用现有 CompanionRuntime 对 Resources/data 的加载布局）。
//   * 远程卡组解析到 Local_Asset_Store 的 `decks/{deckId}/{version}`（应用支持目录下）。
// - 尚未解锁的 Bundled_Deck 计入 Prefetched_Deck_Cache 的 3 个上限且无需下载（Req 6.3）——
//   本类型提供"是否本地可用、无需下载"的判定供预取缓存计数使用。
//
// 该类型为纯值类型 + 可注入文件存在性探测，便于单测（注入 resourcesRoot / appSupportRoot /
// 目录存在闭包），不直接耦合真实文件系统。

/// 一个卡组在本地资源中的位置类型。
///
/// - `bundled`：随应用分发的内置卡组，解析到 `Resources/data/{deckId}`。
/// - `remote`：经 Deck_Worker 授权下载并安装的远程卡组，解析到
///   Local_Asset_Store 的 `decks/{deckId}/{version}`。
public enum DeckLocation: Equatable, Sendable {
    case bundled(deckId: String)
    case remote(deckId: String, version: String)

    public var deckId: String {
        switch self {
        case .bundled(let deckId):
            return deckId
        case .remote(let deckId, _):
            return deckId
        }
    }

    public var isBundled: Bool {
        if case .bundled = self { return true }
        return false
    }
}

/// 内置卡组目录与卡组资源基路径解析。
///
/// 注入 `resourcesRoot`（应用 bundle 的 `Resources` 目录）与 `appSupportRoot`
/// （`~/Library/Application Support/TokeyPal`），以及一个目录存在性探测闭包，
/// 使全部判定与路径解析成为纯逻辑、可单测。
public struct BundledDeckLocator: Sendable {
    /// 随应用分发的免费 Bundled_Deck 的已知 id（Req 6.1）。
    ///
    /// 这是"已知内置卡组集合"——该卡组的资源与数据随包位于 `Resources/data/{id}/`，
    /// 安装后即本地可用、无需任何网络下载。运行时仍以 `Resources/data` 的实际存在性
    /// （`isLocallyAvailableWithoutDownload`）作为最终判定，已知集合用于无文件系统时的稳定判定。
    public static let bundledDeckIds: Set<String> = ["t-rex"]

    /// 应用 bundle 的 `Resources` 目录（含 `data/{id}/`）。
    public let resourcesRoot: URL
    /// `~/Library/Application Support/TokeyPal`（含 `decks/{deckId}/{version}/`）。
    public let appSupportRoot: URL

    private let directoryExists: @Sendable (URL) -> Bool

    public init(
        resourcesRoot: URL,
        appSupportRoot: URL = ResourceLocator.applicationSupportRoot(),
        directoryExists: @escaping @Sendable (URL) -> Bool = BundledDeckLocator.defaultDirectoryExists
    ) {
        self.resourcesRoot = resourcesRoot
        self.appSupportRoot = appSupportRoot
        self.directoryExists = directoryExists
    }

    /// 便捷初始化：从 `ResourceLocator` 取 `Resources` 目录。
    public init(
        resources: ResourceLocator,
        appSupportRoot: URL = ResourceLocator.applicationSupportRoot(),
        directoryExists: @escaping @Sendable (URL) -> Bool = BundledDeckLocator.defaultDirectoryExists
    ) {
        self.init(
            resourcesRoot: resources.resourcesRoot,
            appSupportRoot: appSupportRoot,
            directoryExists: directoryExists
        )
    }

    // MARK: 根目录

    /// 内置卡组数据根：`Resources/data`。
    public var dataRoot: URL {
        resourcesRoot.appendingPathComponent("data", isDirectory: true)
    }

    /// Local_Asset_Store 根：`{appSupport}/decks`。
    public var decksRoot: URL {
        appSupportRoot.appendingPathComponent("decks", isDirectory: true)
    }

    // MARK: 基路径解析（Req 6.1 / 6.3）

    /// 内置卡组基路径：`Resources/data/{deckId}`。
    public func bundledBasePath(deckId: String) -> URL {
        dataRoot.appendingPathComponent(deckId, isDirectory: true)
    }

    /// 远程卡组基路径：Local_Asset_Store 的 `decks/{deckId}/{version}`。
    public func remoteBasePath(deckId: String, version: String) -> URL {
        decksRoot
            .appendingPathComponent(deckId, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }

    /// 按位置类型解析卡组资源基路径。
    ///
    /// - bundled -> `Resources/data/{deckId}`
    /// - remote  -> `{appSupport}/decks/{deckId}/{version}`
    public func basePath(for location: DeckLocation) -> URL {
        switch location {
        case .bundled(let deckId):
            return bundledBasePath(deckId: deckId)
        case .remote(let deckId, let version):
            return remoteBasePath(deckId: deckId, version: version)
        }
    }

    /// 按 `isBundled` 标志解析基路径。
    ///
    /// `isBundled == true` 时解析到 `Resources/data/{deckId}`（`version` 被忽略）；
    /// 否则解析到 `decks/{deckId}/{version}`。
    public func basePath(deckId: String, version: String, isBundled: Bool) -> URL {
        basePath(for: isBundled ? .bundled(deckId: deckId) : .remote(deckId: deckId, version: version))
    }

    // MARK: 本地可用性判定（Req 6.1 / 6.3）

    /// 该 deckId 是否属于已知内置卡组集合（与文件系统无关的稳定判定）。
    public func isKnownBundledDeck(_ deckId: String) -> Bool {
        Self.bundledDeckIds.contains(deckId)
    }

    /// 该 deckId 是否随包位于 `Resources/data/{id}/`，即安装后本地可用、无需任何网络下载（Req 6.1）。
    ///
    /// 基于 `Resources/data` 实际存在性判定，作为运行时是否需要下载的依据。
    public func isLocallyAvailableWithoutDownload(deckId: String) -> Bool {
        directoryExists(bundledBasePath(deckId: deckId))
    }

    /// 已知内置卡组集合中、当前确实随包就位于 `Resources/data/` 的卡组 id（已排序，便于确定性）。
    public func availableBundledDeckIds() -> [String] {
        Self.bundledDeckIds
            .filter { isLocallyAvailableWithoutDownload(deckId: $0) }
            .sorted()
    }

    // MARK: 默认探测

    /// 默认目录存在性探测：基于 `FileManager`，仅当路径存在且为目录时为真。
    public static let defaultDirectoryExists: @Sendable (URL) -> Bool = { url in
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
