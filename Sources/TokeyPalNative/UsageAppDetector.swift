import Foundation

/// 各来源的默认监控目录(下沉自原桥接层 defaultDirectories)。
public func defaultUsageDirectories(for appId: String) -> [String] {
    switch appId {
    case "claude": return ["~/.claude/projects"]
    case "codex": return ["~/.codex/sessions"]
    case "openclaw": return ["~/.openclaw", "~/.clawdbot", "~/.moltbot", "~/.moldbot"]
    case "opencode": return ["~/.local/share/opencode", "~/.config/opencode"]
    case "hermes": return ["~/.hermes"]
    default: return ["~/.\(appId)"]
    }
}

/// 目录检测:命中任一目录即 detected,否则 missing。`fileExistsAsDirectory` 可注入以便测试。
public struct UsageAppDetector: Sendable {
    private let fileExistsAsDirectory: @Sendable (String) -> Bool

    public init(fileExistsAsDirectory: @escaping @Sendable (String) -> Bool = { path in
        var isDir: ObjCBool = false
        let expanded = (path as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
    }) {
        self.fileExistsAsDirectory = fileExistsAsDirectory
    }

    public func detect(appId: String, customDirectories: [String]) -> UsageAppDetectionResult {
        let directories = customDirectories.isEmpty ? defaultUsageDirectories(for: appId) : customDirectories
        let matched = directories.first(where: fileExistsAsDirectory)
        return UsageAppDetectionResult(
            appId: appId,
            status: matched == nil ? "missing" : "detected",
            checkedDirectories: directories,
            matchedPath: matched,
            message: matched == nil
                ? "No local usage directory found. Update the directory above and save again."
                : "Directory is available."
        )
    }
}

/// 默认可见的来源(有序),供 Config / Onboarding 列表使用。
public func visibleUsageApps() -> [UsageAppConfig] {
    orderedUsageApps().filter { $0.visibleByDefault }
}
