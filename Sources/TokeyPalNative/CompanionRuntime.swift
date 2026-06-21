import Foundation

public final class CompanionRuntime {
    private let resources: ResourceLocator
    private let stateURL: URL
    private let startManifest: StartManifest
    private let characters: [String: CharacterManifest]
    private var selectedCharacterId: String
    private var blindBoxModeEnabled = true

    public init(
        resources: ResourceLocator,
        stateURL: URL = ResourceLocator.applicationSupportRoot().appendingPathComponent("blind-box-state.json")
    ) throws {
        self.resources = resources
        self.stateURL = stateURL
        self.startManifest = try Self.loadStartManifest(resources: resources)
        self.characters = try Self.loadCharacterManifests(resources: resources)
        let persistedState = Self.loadPersistedState(stateURL: stateURL)
        if let persistedId = persistedState?.selectedCharacterId, characters.keys.contains(persistedId) {
            self.selectedCharacterId = persistedId
        } else if characters.keys.contains("t-rex") {
            self.selectedCharacterId = "t-rex"
        } else if let first = characters.keys.sorted().first {
            self.selectedCharacterId = first
        } else {
            throw CompanionRuntimeError.noCharacters
        }
        self.blindBoxModeEnabled = persistedState?.blindBoxModeEnabled ?? true
    }

    public func resolve(todayTokens: Int, settings: TokeyPalSettings, action requestedAction: String? = nil) throws -> CompanionState {
        let character = try selectedCharacter()
        let stage = displayStage(todayTokens: todayTokens, thresholds: settings.blindBoxThresholds)
        let resolved = try resolveAssets(character: character, stage: stage)
        let coverFile = first(resolved.metadata.files(for: "cover"))
        let characterFile = first(resolved.metadata.files(for: "character")) ?? coverFile
        let actionFile = requestedAction.flatMap { selectRandomAsset(resolved.metadata.files(for: $0)) }
        let action = actionFile == nil ? nil : requestedAction

        guard let coverFile else {
            throw CompanionRuntimeError.missingVisualAsset(character.id, stage)
        }

        return CompanionState(
            characterId: character.id,
            characterName: character.name,
            displayStage: stage,
            startType: character.startType,
            action: action,
            sizePixels: settings.companion.sizePixels,
            animationUrl: actionFile.map { url(basePath: resolved.basePath, file: $0) },
            coverUrl: url(basePath: resolved.basePath, file: coverFile),
            characterUrl: characterFile.map { url(basePath: resolved.basePath, file: $0) }
        )
    }

    public func buildBlindBoxView(todayTokens: Int, settings: TokeyPalSettings) throws -> BlindBoxView {
        let character = try selectedCharacter()
        let displayStage = displayStage(todayTokens: todayTokens, thresholds: settings.blindBoxThresholds)
        let deckBackUrl = resources.url(relativePath: "assets/deck/back.png").absoluteString
        let stageCards = try (1...4).map { stage -> StageCard in
            let current = stage == displayStage
            if stage == 1 || stage <= displayStage {
                let resolved = try resolveAssets(character: character, stage: stage)
                if let cover = first(resolved.metadata.files(for: "cover")) {
                    return StageCard(
                        kind: "front",
                        stage: stage,
                        current: current,
                        url: nil,
                        layers: [CardLayer(role: "cover", url: url(basePath: resolved.basePath, file: cover))]
                    )
                }
            }
            return StageCard(kind: "back", stage: stage, current: current, url: deckBackUrl, layers: nil)
        }

        let collection = try characters.keys.sorted().map { id -> CollectionCardView in
            let manifest = try characterManifest(id: id)
            let unlocked = id == character.id && displayStage > 1
            let stageCoverUrls = try stageCoverUrls(for: manifest, through: unlocked ? displayStage : 1)
            let coverUrl = stageCoverUrls[String(unlocked ? displayStage : 1)]
            let layers = coverUrl.map { [CardLayer(role: "cover", url: $0)] }
            return CollectionCardView(
                id: id,
                name: manifest.name,
                unlocked: unlocked,
                stage: unlocked ? displayStage : nil,
                stageCoverUrls: stageCoverUrls,
                selected: id == character.id,
                selectable: id == character.id,
                firstUnlockedAt: nil,
                coverUrl: coverUrl,
                layers: layers,
                stageCards: buildCollectionStageCards(stageCoverUrls: stageCoverUrls, displayStage: unlocked ? displayStage : 1, deckBackUrl: deckBackUrl)
            )
        }

        return BlindBoxView(
            todayTokens: todayTokens,
            deckBackUrl: deckBackUrl,
            currentMode: BlindBoxMode(blindBoxModeEnabled: blindBoxModeEnabled),
            displayStage: displayStage,
            stageCards: stageCards,
            progressPercent: progressPercent(displayStage: displayStage, todayTokens: todayTokens, thresholds: settings.blindBoxThresholds),
            progressSegments: buildProgressSegments(todayTokens: todayTokens, thresholds: settings.blindBoxThresholds),
            stageMarkers: (1...4).map { StageMarker(stage: $0, label: "Stage \($0)", reached: $0 <= displayStage) },
            collection: collection
        )
    }

    public func debugManifestsView() -> DebugManifestsView {
        let characters = characters.values.sorted { $0.id < $1.id }.map { character in
            DebugCharacterView(
                id: character.id,
                name: character.name,
                startType: character.startType,
                stages: (1...4).compactMap { stage in
                    guard let resolved = try? resolveAssets(character: character, stage: stage) else {
                        return nil
                    }
                    return DebugStageView(
                        stage: stage,
                        actions: ["cover", "character", "idle", "hover", "click", "evolve"].map { action in
                            let files = resolved.metadata.files(for: action)
                            return DebugActionView(
                                action: action,
                                files: files,
                                urls: files.map { url(basePath: resolved.basePath, file: $0) }
                            )
                        }
                    )
                }
            )
        }
        return DebugManifestsView(characters: characters)
    }

    /// 播放前所需的本地资源文件 URL 列表（当前选中角色 + 由 todayTokens 推导的阶段）。
    ///
    /// 复用既有 `resolveAssets` 资源布局，至少包含 cover；若 metadata 提供 character 静态图也纳入。
    /// 这些 URL 指向本地 `Resources/data` / `assets`（Bundled_Deck），不依赖网络（Req 7.5）。
    public func requiredResourceURLs(todayTokens: Int, settings: TokeyPalSettings) throws -> [URL] {
        let character = try selectedCharacter()
        let stage = displayStage(todayTokens: todayTokens, thresholds: settings.blindBoxThresholds)
        let resolved = try resolveAssets(character: character, stage: stage)
        guard let cover = first(resolved.metadata.files(for: "cover")) else {
            throw CompanionRuntimeError.missingVisualAsset(character.id, stage)
        }
        var urls = [resources.url(relativePath: "\(resolved.basePath)/\(cover)")]
        if let characterFile = first(resolved.metadata.files(for: "character")) {
            urls.append(resources.url(relativePath: "\(resolved.basePath)/\(characterFile)"))
        }
        return urls
    }

    /// 播放前校验当前选中角色所需的 Local_Asset_Store 资源是否齐全（Req 7.5 / 7.6, Property 28）。
    ///
    /// 仅通过注入的 `fileExists` 探测本地文件系统，**不依赖网络**。缺失任一所需资源（或无法解析
    /// 资源布局）时返回 `abortMissingResources`，中止本次播放并给出缺失资源指示；调用方据此中止
    /// 播放，且**不**回滚 / 重新随机今日伴侣选择（选择不变由调用方对 Local_State 只读保证）。
    public func verifyPlayableResources(
        todayTokens: Int,
        settings: TokeyPalSettings,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> PrePlayResourceOutcome {
        let urls: [URL]
        do {
            urls = try requiredResourceURLs(todayTokens: todayTokens, settings: settings)
        } catch {
            // 无法解析资源布局（缺 metadata / 阶段）：按资源缺失处理，中止播放。
            return .abortMissingResources(missing: ["metadata.json"])
        }
        let missing = urls.filter { !fileExists($0) }.map { $0.lastPathComponent }
        return missing.isEmpty ? .play : .abortMissingResources(missing: missing)
    }

    public func setBlindBoxMode(_ enabled: Bool) {
        blindBoxModeEnabled = enabled
        persistSelectionState()
    }

    public func selectCharacter(_ id: String) throws {
        guard characters[id] != nil else {
            throw CompanionRuntimeError.missingCharacter(id)
        }
        selectedCharacterId = id
        blindBoxModeEnabled = false
        persistSelectionState()
    }

    private func persistSelectionState() {
        let state = CompanionRuntimePersistedState(
            selectedCharacterId: selectedCharacterId,
            blindBoxModeEnabled: blindBoxModeEnabled
        )
        do {
            let directory = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: stateURL, options: .atomic)
        } catch {
            // Selection persistence should not break companion rendering.
        }
    }

    private func selectedCharacter() throws -> CharacterManifest {
        try characterManifest(id: selectedCharacterId)
    }

    private func characterManifest(id: String) throws -> CharacterManifest {
        guard let character = characters[id] else {
            throw CompanionRuntimeError.missingCharacter(id)
        }
        return character
    }

    private func resolveAssets(character: CharacterManifest, stage: Int) throws -> (basePath: String, metadata: StageMetadata) {
        if stage == 1 {
            guard let metadata = startManifest.types[character.startType] else {
                throw CompanionRuntimeError.missingStartType(character.startType)
            }
            return ("assets/start/\(character.startType)", metadata)
        }

        guard let metadata = character.stages[stage] else {
            throw CompanionRuntimeError.missingStage(character.id, stage)
        }
        return ("data/\(character.id)/\(stage)", metadata)
    }

    private func stageCoverUrls(for character: CharacterManifest, through displayStage: Int) throws -> [String: String] {
        var urls: [String: String] = [:]
        for stage in 1...4 where stage == 1 || stage <= displayStage {
            let resolved = try resolveAssets(character: character, stage: stage)
            if let cover = first(resolved.metadata.files(for: "cover")) {
                urls[String(stage)] = url(basePath: resolved.basePath, file: cover)
            }
        }
        return urls
    }

    private func buildCollectionStageCards(stageCoverUrls: [String: String], displayStage: Int, deckBackUrl: String) -> [StageCard] {
        (1...4).map { stage in
            if let cover = stageCoverUrls[String(stage)], stage == 1 || stage <= displayStage {
                return StageCard(
                    kind: "front",
                    stage: stage,
                    current: false,
                    url: nil,
                    layers: [CardLayer(role: "cover", url: cover)]
                )
            }
            return StageCard(kind: "back", stage: stage, current: false, url: deckBackUrl, layers: nil)
        }
    }

    private func url(basePath: String, file: String) -> String {
        resources.url(relativePath: "\(basePath)/\(file)").absoluteString
    }

    private static func loadStartManifest(resources: ResourceLocator) throws -> StartManifest {
        let root = try readJSON(resources.assetsRoot.appendingPathComponent("start/metadata.json"))
        let types = dictionary(root["types"]) ?? root
        return StartManifest(types: [
            "egg": parseStage(types["egg"]),
            "box": parseStage(types["box"])
        ])
    }

    private static func loadCharacterManifests(resources: ResourceLocator) throws -> [String: CharacterManifest] {
        let fileManager = FileManager.default
        let entries = try fileManager.contentsOfDirectory(at: resources.dataRoot, includingPropertiesForKeys: [.isDirectoryKey])
        var result: [String: CharacterManifest] = [:]

        for directory in entries {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                continue
            }

            let metadataURL = directory.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                continue
            }

            let id = directory.lastPathComponent
            let root = try readJSON(metadataURL)
            let stagesRoot = dictionary(root["stages"]) ?? [:]
            var stages: [Int: StageMetadata] = [:]
            for (key, value) in stagesRoot {
                if let stage = Int(key), (2...4).contains(stage) {
                    stages[stage] = parseStage(value)
                }
            }
            result[id] = CharacterManifest(
                id: id,
                name: string(root["name"]) ?? id,
                persona: string(root["persona"]) ?? "",
                startType: string(root["startType"]) ?? "egg",
                stages: stages
            )
        }

        return result
    }

    private static func loadPersistedState(stateURL: URL) -> CompanionRuntimePersistedState? {
        guard FileManager.default.fileExists(atPath: stateURL.path),
              let data = try? Data(contentsOf: stateURL) else {
            return nil
        }
        return try? JSONDecoder().decode(CompanionRuntimePersistedState.self, from: data)
    }
}

private struct CompanionRuntimePersistedState: Codable, Equatable {
    var selectedCharacterId: String
    var blindBoxModeEnabled: Bool
}

enum CompanionRuntimeError: Error, Equatable {
    case noCharacters
    case missingCharacter(String)
    case missingStartType(String)
    case missingStage(String, Int)
    case missingVisualAsset(String, Int)
}

private func displayStage(todayTokens: Int, thresholds: BlindBoxThresholds) -> Int {
    if todayTokens >= thresholds.stage4TokenThreshold {
        return 4
    }
    if todayTokens >= thresholds.stage3TokenThreshold {
        return 3
    }
    if todayTokens >= thresholds.stage2TokenThreshold {
        return 2
    }
    return 1
}

private func progressPercent(displayStage: Int, todayTokens: Int, thresholds: BlindBoxThresholds) -> Double {
    let next: Int?
    switch displayStage {
    case 1:
        next = thresholds.stage2TokenThreshold
    case 2:
        next = thresholds.stage3TokenThreshold
    case 3:
        next = thresholds.stage4TokenThreshold
    default:
        next = nil
    }

    guard let next, next > 0 else {
        return 100
    }
    return max(0, min(100, Double(todayTokens) / Double(next) * 100))
}

private func buildProgressSegments(todayTokens: Int, thresholds: BlindBoxThresholds) -> [StageProgressSegment] {
    let ranges = [
        (0, thresholds.stage2TokenThreshold),
        (thresholds.stage2TokenThreshold, thresholds.stage3TokenThreshold),
        (thresholds.stage3TokenThreshold, thresholds.stage4TokenThreshold),
        (thresholds.stage4TokenThreshold, thresholds.stage4TokenThreshold)
    ]

    return ranges.map { from, to in
        let percent: Int
        if to <= from {
            percent = todayTokens >= to ? 100 : 0
        } else {
            percent = max(0, min(100, Int(((Double(todayTokens - from) / Double(to - from)) * 100).rounded())))
        }
        return StageProgressSegment(from: from, to: to, percent: percent, filled: percent >= 100)
    }
}

private func first(_ files: [String]) -> String? {
    files.first
}

func selectRandomAsset(_ files: [String], random: () -> Double = { Double.random(in: 0..<1) }) -> String? {
    guard !files.isEmpty else {
        return nil
    }
    let index = max(0, min(Int(random() * Double(files.count)), files.count - 1))
    return files[index]
}

private func readJSON(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try dictionary(JSONSerialization.jsonObject(with: data)) ?? [:]
}

private func parseStage(_ value: Any?) -> StageMetadata {
    let root = dictionary(value) ?? [:]
    let visual = dictionary(root["visual"]) ?? [:]
    return StageMetadata(
        story: string(root["story"]) ?? "",
        visual: [
            "cover": stringArray(visual["cover"]),
            "evolve": stringArray(visual["evolve"]),
            "idle": stringArray(visual["idle"]),
            "hover": stringArray(visual["hover"]),
            "click": stringArray(visual["click"]),
            "character": stringArray(visual["character"])
        ]
    )
}

private func dictionary(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

private func string(_ value: Any?) -> String? {
    value as? String
}

private func stringArray(_ value: Any?) -> [String] {
    (value as? [Any])?.compactMap { $0 as? String }.filter { !$0.isEmpty } ?? []
}
