import Foundation

public struct StageMetadata: Equatable, Sendable {
    public var story: String
    public var visual: [String: [String]]

    func files(for action: String) -> [String] {
        visual[action] ?? []
    }
}

public struct StartManifest: Equatable, Sendable {
    public var types: [String: StageMetadata]
}

public struct CharacterManifest: Equatable, Sendable {
    public var id: String
    public var name: String
    public var persona: String
    public var startType: String
    public var stages: [Int: StageMetadata]
}

public struct CompanionState: Codable, Equatable, Sendable {
    public var characterId: String
    public var characterName: String
    public var displayStage: Int
    public var startType: String
    public var action: String?
    public var sizePixels: Int
    public var animationUrl: String?
    public var coverUrl: String
    public var characterUrl: String?
}

public struct CardLayer: Codable, Equatable, Sendable {
    public var role: String
    public var url: String
}

public struct StageProgressSegment: Codable, Equatable, Sendable {
    public var from: Int
    public var to: Int
    public var percent: Int
    public var filled: Bool
}

public struct StageMarker: Codable, Equatable, Sendable {
    public var stage: Int
    public var label: String
    public var reached: Bool
}

public struct StageCard: Codable, Equatable, Sendable {
    public var kind: String
    public var stage: Int
    public var current: Bool
    public var url: String?
    public var layers: [CardLayer]?
}

public struct CollectionCardView: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var unlocked: Bool
    public var stage: Int?
    public var stageCoverUrls: [String: String]?
    public var selected: Bool
    public var selectable: Bool
    public var firstUnlockedAt: String?
    public var coverUrl: String?
    public var layers: [CardLayer]?
    public var stageCards: [StageCard]
    /// 该卡组的远程资源下载 / 校验是否失败（Req 9.6 / Property 33）。
    /// 为 `true` 时 Dashboard 应展示可见的失败状态提示。默认 `false`。
    public var downloadFailed: Bool = false
    /// 失败提示文案（来源于安装记录的 `lastError`）。仅当 `downloadFailed == true` 时有意义。
    public var failureMessage: String? = nil
}

public struct BlindBoxMode: Codable, Equatable, Sendable {
    public var blindBoxModeEnabled: Bool
}

public struct BlindBoxView: Codable, Equatable, Sendable {
    public var todayTokens: Int
    public var deckBackUrl: String
    public var currentMode: BlindBoxMode
    public var displayStage: Int
    public var stageCards: [StageCard]
    public var progressPercent: Double
    public var progressSegments: [StageProgressSegment]
    public var stageMarkers: [StageMarker]
    public var collection: [CollectionCardView]
}

public struct DebugActionView: Codable, Equatable, Sendable {
    public var action: String
    public var files: [String]
    public var urls: [String]
}

public struct DebugStageView: Codable, Equatable, Sendable {
    public var stage: Int
    public var actions: [DebugActionView]
}

public struct DebugCharacterView: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var startType: String
    public var stages: [DebugStageView]
}

public struct DebugManifestsView: Codable, Equatable, Sendable {
    public var characters: [DebugCharacterView]
}
