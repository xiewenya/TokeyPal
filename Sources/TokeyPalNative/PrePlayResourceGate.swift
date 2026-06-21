import Foundation

// MARK: - 播放前本地资源校验门禁（PrePlayResourceGate / PrePlayResourceVerifier）
//
// 映射 Requirement 7.5 / 7.6 与设计文档 Correctness Property 28
// （缺失本地资源中止播放且选择不变）。
//
// 设计要点（与 design.md 一致）：
// - 伴侣即将播放某个卡组角色前，必须先校验 Local_Asset_Store 中已存在该卡组所需资源，
//   且**不依赖网络**实时获取资源（Req 7.5）。校验只通过注入的文件存在性探测 `fileExists`
//   读取本地文件系统，绝不发起任何网络请求。
// - 若缺失所需资源，则中止该卡组的本次播放、给出"资源缺失"指示（缺失资源的相对路径列表），
//   并**保留当前今日候选池与今日伴侣选择不变**——不回滚、不重新随机（Req 7.6）。
// - 卡组资源基路径解析复用 `BundledDeckLocator`：bundled → `Resources/data/{id}`、
//   remote → Local_Asset_Store 的 `decks/{deckId}/{version}`。
//
// 全部为纯逻辑（无可变状态、注入文件探测），便于属性化测试与确定性复现。

/// 播放前资源校验结果（Req 7.5 / 7.6, Property 28）。
public enum PrePlayResourceOutcome: Equatable, Sendable {
    /// 所需资源齐全，可以播放。
    case play
    /// 缺失资源：中止本次播放，附带缺失资源的相对路径（用于向用户提示资源缺失）。
    case abortMissingResources(missing: [String])

    /// 是否可以播放。
    public var canPlay: Bool {
        if case .play = self { return true }
        return false
    }

    /// 是否因缺失资源而中止。
    public var aborted: Bool { !canPlay }

    /// 缺失资源的相对路径列表（`play` 时为空）。
    public var missingResources: [String] {
        if case .abortMissingResources(let missing) = self { return missing }
        return []
    }
}

/// 播放前本地资源校验器（纯逻辑 + 注入的文件存在性探测）。
///
/// 注入 `BundledDeckLocator`（解析 bundled / remote 卡组资源基路径）与一个
/// `fileExists` 探测闭包，使全部校验成为纯逻辑、可单测，且**不触达网络**。
public struct PrePlayResourceVerifier: Sendable {
    private let locator: BundledDeckLocator
    private let fileExists: @Sendable (URL) -> Bool

    /// - Parameters:
    ///   - locator: 卡组资源基路径解析器（bundled / remote）。
    ///   - fileExists: 文件存在性探测（默认基于 `FileManager`，仅读取本地文件系统，不联网）。
    public init(
        locator: BundledDeckLocator,
        fileExists: @escaping @Sendable (URL) -> Bool = PrePlayResourceVerifier.defaultFileExists
    ) {
        self.locator = locator
        self.fileExists = fileExists
    }

    // MARK: 缺失资源检测（Req 7.5）

    /// 纯逻辑：列出某卡组在 Local_Asset_Store 中缺失的所需资源（相对路径）。
    ///
    /// 行为契约：
    /// - 基路径由 `BundledDeckLocator` 按 `location` 解析（bundled → `Resources/data/{id}`，
    ///   remote → `decks/{deckId}/{version}`）。
    /// - 对每个所需资源相对路径，通过注入的 `fileExists` 探测 `basePath/{relative}` 是否存在。
    /// - 返回缺失项，按 `required` 的输入顺序保留、去重（保证确定性，便于稳定提示）。
    /// - 不发起任何网络请求（只读本地文件系统）。
    public func missingResources(location: DeckLocation, required: [String]) -> [String] {
        let base = locator.basePath(for: location)
        var seen = Set<String>()
        var missing: [String] = []
        for relative in required {
            // 去重：相同相对路径只检测一次。
            guard !seen.contains(relative) else { continue }
            seen.insert(relative)
            let url = base.appendingPathComponent(relative)
            if !fileExists(url) {
                missing.append(relative)
            }
        }
        return missing
    }

    // MARK: 播放前校验决策（Req 7.6 / Property 28）

    /// 纯逻辑：播放前资源校验决策。
    ///
    /// 缺失任一所需资源 → `abortMissingResources`（中止本次播放、附带缺失列表）；
    /// 所需资源齐全 → `play`。`required` 为空视为无资源要求，返回 `play`。
    public func verify(location: DeckLocation, required: [String]) -> PrePlayResourceOutcome {
        let missing = missingResources(location: location, required: required)
        return missing.isEmpty ? .play : .abortMissingResources(missing: missing)
    }

    // MARK: 默认探测

    /// 默认文件存在性探测：基于 `FileManager`，路径存在（文件或目录）即为真。仅读取本地文件系统。
    public static let defaultFileExists: @Sendable (URL) -> Bool = { url in
        FileManager.default.fileExists(atPath: url.path)
    }
}

/// 播放前资源校验的"选择不变"不变式（Req 7.6, Property 28）。
///
/// 把"播放前校验对 Local_State 只读——不回滚、不重新随机"显式表达为纯函数，
/// 便于属性化测试断言"中止播放不产生任何本地写回 / 不改变今日伴侣选择"。
public enum PrePlayResourceGate {
    /// 纯逻辑：播放前校验后应当持久化的 Local_State。
    ///
    /// 行为契约：无论校验结果为 `play` 还是 `abortMissingResources`，对任意输入 `localState`
    /// 返回值恒等于输入——播放前校验**绝不**改变今日伴侣选择（`todaySelection`）、候选池
    /// 相关状态或任何收藏进度（不回滚、不重新随机，Req 7.6）。
    public static func stateAfterPlayGate(
        _ localState: LocalState,
        outcome: PrePlayResourceOutcome
    ) -> LocalState {
        _ = outcome // 校验仅做读操作，无副作用。
        return localState
    }
}
