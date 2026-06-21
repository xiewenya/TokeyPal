import Foundation
import Testing
@testable import TokeyPalNative

// MARK: - 测试支撑

/// 确定性可复现的伪随机数生成器（线性同余），保证属性测试可重放。
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

/// 固定的应用支持根与 Resources 根，保证路径解析确定。
private func makeLocator(directoryExists: @escaping @Sendable (URL) -> Bool = { _ in true }) -> BundledDeckLocator {
    BundledDeckLocator(
        resourcesRoot: URL(fileURLWithPath: "/test/Resources", isDirectory: true),
        appSupportRoot: URL(fileURLWithPath: "/test/AppSupport/TokeyPal", isDirectory: true),
        directoryExists: directoryExists
    )
}

private let candidateResources = ["metadata.json", "2/card.png", "3/cover.png", "4/idle.webp"]

/// 线程安全的本地文件探测包装，统计探测次数（用于断言"校验只做本地探测、不联网"）。
private final class LocalProbe: @unchecked Sendable {
    private let body: @Sendable (URL) -> Bool
    private let lock = NSLock()
    private var _count = 0
    init(_ body: @escaping @Sendable (URL) -> Bool) { self.body = body }
    func exists(_ url: URL) -> Bool {
        lock.lock(); _count += 1; lock.unlock()
        return body(url)
    }
    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return _count
    }
}

// MARK: - 属性化测试

// Property: 缺失本地资源中止播放且选择不变
//
// 对于任意即将播放的卡组，若 Local_Asset_Store 缺失其所需资源，则中止本次播放、提示资源缺失，
// 且播放前校验不依赖网络（只读本地文件系统）。
// Validates: Requirements 7.5, 7.6

@Test func property_missingResourcesAbortsPlayAndStateUnchanged() {
    var rng = SeededGenerator(seed: 0x9128_0028_5EED)
    let iterations = 240

    for i in 0..<iterations {
        let deckId = "deck-\(i)"
        let version = "1.\(i).0"
        let isBundled = Bool.random(using: &rng)
        let location: DeckLocation = isBundled
            ? .bundled(deckId: deckId)
            : .remote(deckId: deckId, version: version)

        // 随机抽取一个非空所需资源子集（保证至少 1 个，便于制造缺失）。
        var required: [String] = candidateResources.filter { _ in Bool.random(using: &rng) }
        if required.isEmpty { required = [candidateResources[0]] }

        // 随机决定每个所需资源是否存在于本地（注入文件探测）。
        var presence: [String: Bool] = [:]
        for r in required { presence[r] = Bool.random(using: &rng) }
        let base = makeLocator().basePath(for: location)
        let presenceCopy = presence
        // 统计本地探测次数（线程安全引用计数），用于确认"校验只做本地探测、不联网"。
        let probe = LocalProbe { url in
            // 仅读本地文件系统语义：依据 base + 相对路径查表（不联网）。
            let relative = String(url.path.dropFirst(base.path.count).drop(while: { $0 == "/" }))
            return presenceCopy[relative] ?? false
        }

        let verifier = PrePlayResourceVerifier(locator: makeLocator(), fileExists: { probe.exists($0) })
        let outcome = verifier.verify(location: location, required: required)

        let expectedMissing = required.filter { presence[$0] != true }

        if expectedMissing.isEmpty {
            // 所需资源齐全 -> 可播放。
            #expect(outcome == .play)
            #expect(outcome.canPlay)
            #expect(!outcome.aborted)
        } else {
            // 缺失任一所需资源 -> 中止播放、提示缺失（缺失列表 == 期望缺失，保序去重）。
            #expect(outcome.aborted)
            #expect(!outcome.canPlay)
            #expect(outcome.missingResources == dedupePreservingOrder(expectedMissing),
                    "缺失资源指示必须精确等于实际缺失的所需资源")
        }

        // 不依赖网络：verify 只通过注入的本地探测读取（probe 次数 == 去重后的所需资源数）。
        #expect(probe.count == dedupePreservingOrder(required).count,
                "校验只对每个去重后的所需资源做一次本地探测，不发起任何网络请求")

        // 选择不变（Req 7.6）：构造任意 Local_State，校验后必须恒等。
        var localState = LocalState.default
        localState.selectedCharacterId = deckId
        localState.blindBoxModeEnabled = Bool.random(using: &rng)

        let after = PrePlayResourceGate.stateAfterPlayGate(localState, outcome: outcome)
        #expect(after == localState, "播放前校验对 Local_State 只读——选择不变")
    }
}

/// 保序去重（与 PrePlayResourceVerifier.missingResources 的口径一致）。
private func dedupePreservingOrder(_ items: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for item in items where !seen.contains(item) {
        seen.insert(item)
        result.append(item)
    }
    return result
}

// MARK: - 单元测试（代表性示例）

@Test func verifier_allResourcesPresentPlays() {
    let verifier = PrePlayResourceVerifier(locator: makeLocator(), fileExists: { _ in true })
    let outcome = verifier.verify(location: .bundled(deckId: "t-rex"), required: ["metadata.json", "2/card.png"])
    #expect(outcome == .play)
}

@Test func verifier_missingResourceAbortsWithIndication() {
    let base = makeLocator().basePath(for: .remote(deckId: "aurora", version: "2026.01.06"))
    let verifier = PrePlayResourceVerifier(locator: makeLocator(), fileExists: { url in
        // metadata.json 存在，但 2/card.png 缺失。
        url == base.appendingPathComponent("metadata.json")
    })
    let outcome = verifier.verify(location: .remote(deckId: "aurora", version: "2026.01.06"),
                                  required: ["metadata.json", "2/card.png"])
    #expect(outcome == .abortMissingResources(missing: ["2/card.png"]))
    #expect(outcome.missingResources == ["2/card.png"])
}

@Test func verifier_resolvesBundledVsRemoteBasePath() {
    let locator = makeLocator()
    let bundledBase = locator.basePath(for: .bundled(deckId: "t-rex"))
    let remoteBase = locator.basePath(for: .remote(deckId: "aurora", version: "v1"))
    #expect(bundledBase.path == "/test/Resources/data/t-rex")
    #expect(remoteBase.path == "/test/AppSupport/TokeyPal/decks/aurora/v1")
}

@Test func gate_stateAfterPlayGateIsReadOnly() {
    var state = LocalState.default
    state.selectedCharacterId = "t-rex"
    state.blindBoxModeEnabled = false
    // 无论 play 还是 abort，状态都不变。
    #expect(PrePlayResourceGate.stateAfterPlayGate(state, outcome: .play) == state)
    #expect(PrePlayResourceGate.stateAfterPlayGate(state, outcome: .abortMissingResources(missing: ["2/card.png"])) == state)
}

@Test func companionRuntime_verifyPlayableResourcesPlaysWhenLocalAssetsExist() throws {
    let resources = ResourceLocator(projectRoot: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
    let runtime = try CompanionRuntime(resources: resources)
    // 真实 bundled 资源存在 -> play（默认 FileManager 探测，不联网）。
    let outcome = runtime.verifyPlayableResources(todayTokens: 0, settings: .default)
    #expect(outcome == .play)
}

@Test func companionRuntime_verifyPlayableResourcesAbortsWhenLocalAssetsMissing() throws {
    let resources = ResourceLocator(projectRoot: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
    let runtime = try CompanionRuntime(resources: resources)
    // 注入"恒不存在"探测 -> 中止播放并提示缺失，不依赖网络。
    let outcome = runtime.verifyPlayableResources(todayTokens: 0, settings: .default, fileExists: { _ in false })
    #expect(outcome.aborted)
    #expect(!outcome.missingResources.isEmpty)
}
