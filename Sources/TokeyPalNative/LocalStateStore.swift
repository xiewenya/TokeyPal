import Foundation

// MARK: - Local_State 数据模型与持久化
//
// 开源版精简：仅保留运行时实际使用的 `selectedCharacterId` 与 `blindBoxModeEnabled`
// 两个字段（远程下载 / 订阅 / 收藏进度子系统已移除）。
//
// 设计要点：
// - 与现有 `~/Library/Application Support/TokeyPal/blind-box-state.json` 兼容：旧文件只含
//   `selectedCharacterId` 与 `blindBoxModeEnabled` 两个字段；读取旧文件必须成功并对缺失字段取默认值。
// - 原子读写（与 SettingsStore / UsageCacheStore 约定一致）：写入用 `.atomic`；
//   读取缺失 / 损坏文件返回默认值。

/// 精简后的 Local_State（与现有 blind-box-state.json 向后兼容）。
///
/// 解码对缺失字段宽容（`decodeIfPresent` + 默认值），旧版文件依然可以成功解码。
public struct LocalState: Codable, Equatable, Sendable {
    /// 当前选中的伴侣角色 id。
    public var selectedCharacterId: String?
    /// 是否启用盲盒模式（缺省为 true，与 CompanionRuntime 默认一致）。
    public var blindBoxModeEnabled: Bool

    public init(
        selectedCharacterId: String? = nil,
        blindBoxModeEnabled: Bool = true
    ) {
        self.selectedCharacterId = selectedCharacterId
        self.blindBoxModeEnabled = blindBoxModeEnabled
    }

    /// 默认 Local_State：未选角色、盲盒模式开启。
    public static let `default` = LocalState()

    private enum CodingKeys: String, CodingKey {
        case selectedCharacterId
        case blindBoxModeEnabled
    }

    /// 宽容解码：缺失字段取默认值，保证旧版 blind-box-state.json 可成功解码。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedCharacterId = try container.decodeIfPresent(String.self, forKey: .selectedCharacterId)
        blindBoxModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .blindBoxModeEnabled) ?? true
    }
}

// MARK: - LocalStateStore

/// Local_State 的读写抽象。`read()` 永不抛错（缺失 / 损坏返回默认值）；`update` 原子写入。
public protocol LocalStateStore: Sendable {
    /// 读取当前 Local_State；缺失 / 损坏文件返回 `.default`。
    func read() -> LocalState
    /// 以读-改-写方式原子地更新 Local_State。
    func update(_ transform: (inout LocalState) -> Void) throws
}

/// 基于文件系统的 `LocalStateStore` 实现（原子写入，约定同 SettingsStore / UsageCacheStore）。
///
/// 默认指向现有 `~/Library/Application Support/TokeyPal/blind-box-state.json`，
/// 因此能就地兼容地演进旧文件。
public struct FileLocalStateStore: LocalStateStore {
    public let stateURL: URL

    public init(
        stateURL: URL = ResourceLocator.applicationSupportRoot().appendingPathComponent("blind-box-state.json")
    ) {
        self.stateURL = stateURL
    }

    public func read() -> LocalState {
        guard FileManager.default.fileExists(atPath: stateURL.path),
              let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(LocalState.self, from: data) else {
            return .default
        }
        return state
    }

    public func update(_ transform: (inout LocalState) -> Void) throws {
        var state = read()
        transform(&state)

        let directory = stateURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }
}
