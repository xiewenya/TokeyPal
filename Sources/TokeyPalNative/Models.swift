import Foundation

public struct Bounds: Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum ThemeMode: String, Codable, Equatable, Sendable {
    case system
    case light
    case dark

    public static func normalized(_ value: ThemeMode?) -> ThemeMode {
        value ?? .system
    }
}

public struct AppearanceSettings: Codable, Equatable, Sendable {
    public var theme: ThemeMode

    public static let `default` = AppearanceSettings(theme: .system)

    public init(theme: ThemeMode) {
        self.theme = theme
    }
}

public struct PollingSettings: Codable, Equatable, Sendable {
    public var idlePollingIntervalMs: Int
    public var activePollingIntervalMs: Int
    public var activeWindowMs: Int

    public static let `default` = PollingSettings(
        idlePollingIntervalMs: 60_000,
        activePollingIntervalMs: 10_000,
        activeWindowMs: 300_000
    )

    public init(idlePollingIntervalMs: Int, activePollingIntervalMs: Int, activeWindowMs: Int) {
        self.idlePollingIntervalMs = idlePollingIntervalMs
        self.activePollingIntervalMs = activePollingIntervalMs
        self.activeWindowMs = activeWindowMs
    }

    public func normalized() -> PollingSettings {
        PollingSettings(
            idlePollingIntervalMs: clamp(idlePollingIntervalMs, min: 30_000, max: 300_000),
            activePollingIntervalMs: clamp(activePollingIntervalMs, min: 10_000, max: 60_000),
            activeWindowMs: clamp(activeWindowMs, min: 60_000, max: 600_000)
        )
    }
}

public struct PollingSettingsPatch: Codable, Equatable, Sendable {
    public var idlePollingIntervalMs: Int?
    public var activePollingIntervalMs: Int?
    public var activeWindowMs: Int?

    init(
        idlePollingIntervalMs: Int? = nil,
        activePollingIntervalMs: Int? = nil,
        activeWindowMs: Int? = nil
    ) {
        self.idlePollingIntervalMs = idlePollingIntervalMs
        self.activePollingIntervalMs = activePollingIntervalMs
        self.activeWindowMs = activeWindowMs
    }

    init(_ settings: PollingSettings) {
        self.init(
            idlePollingIntervalMs: settings.idlePollingIntervalMs,
            activePollingIntervalMs: settings.activePollingIntervalMs,
            activeWindowMs: settings.activeWindowMs
        )
    }
}

public struct BlindBoxThresholds: Codable, Equatable, Sendable {
    public var stage2TokenThreshold: Int
    public var stage3TokenThreshold: Int
    public var stage4TokenThreshold: Int

    public static let `default` = BlindBoxThresholds(
        stage2TokenThreshold: 1,
        stage3TokenThreshold: 50_000_000,
        stage4TokenThreshold: 500_000_000
    )

    public init(stage2TokenThreshold: Int, stage3TokenThreshold: Int, stage4TokenThreshold: Int) {
        self.stage2TokenThreshold = stage2TokenThreshold
        self.stage3TokenThreshold = stage3TokenThreshold
        self.stage4TokenThreshold = stage4TokenThreshold
    }

    public func normalized() -> BlindBoxThresholds {
        let maxThreshold = 100_000_000_000
        let stage2 = clamp(stage2TokenThreshold, min: 1, max: maxThreshold - 2)
        let stage3 = clamp(stage3TokenThreshold, min: stage2 + 1, max: maxThreshold - 1)
        let stage4 = clamp(stage4TokenThreshold, min: stage3 + 1, max: maxThreshold)
        return BlindBoxThresholds(
            stage2TokenThreshold: stage2,
            stage3TokenThreshold: stage3,
            stage4TokenThreshold: stage4
        )
    }
}

public struct BlindBoxThresholdsPatch: Codable, Equatable, Sendable {
    public var stage2TokenThreshold: Int?
    public var stage3TokenThreshold: Int?
    public var stage4TokenThreshold: Int?
    public var starter: Int?
    public var high: Int?
    public var ultimate: Int?

    init(
        stage2TokenThreshold: Int? = nil,
        stage3TokenThreshold: Int? = nil,
        stage4TokenThreshold: Int? = nil,
        starter: Int? = nil,
        high: Int? = nil,
        ultimate: Int? = nil
    ) {
        self.stage2TokenThreshold = stage2TokenThreshold
        self.stage3TokenThreshold = stage3TokenThreshold
        self.stage4TokenThreshold = stage4TokenThreshold
        self.starter = starter
        self.high = high
        self.ultimate = ultimate
    }

    init(_ settings: BlindBoxThresholds) {
        self.init(
            stage2TokenThreshold: settings.stage2TokenThreshold,
            stage3TokenThreshold: settings.stage3TokenThreshold,
            stage4TokenThreshold: settings.stage4TokenThreshold
        )
    }
}

public enum CompanionSizeMode: String, Codable, Equatable, Sendable {
    case small
    case medium
    case large

    public var pixels: Int {
        switch self {
        case .small:
            return 240
        case .medium:
            return 360
        case .large:
            return 480
        }
    }
}

public struct CompanionSettings: Codable, Equatable, Sendable {
    public var bounds: Bounds?
    public var locked: Bool
    public var alwaysOnTop: Bool
    public var size: CompanionSizeMode

    public static let `default` = CompanionSettings(
        bounds: nil,
        locked: false,
        alwaysOnTop: true,
        size: .medium
    )

    public var sizePixels: Int {
        size.pixels
    }

    public init(bounds: Bounds?, locked: Bool, alwaysOnTop: Bool, size: CompanionSizeMode) {
        self.bounds = bounds
        self.locked = locked
        self.alwaysOnTop = alwaysOnTop
        self.size = size
    }

    public func normalized() -> CompanionSettings {
        var next = self
        if let bounds {
            next.bounds = Bounds(x: bounds.x, y: bounds.y, width: sizePixels, height: sizePixels)
        }
        return next
    }
}

public struct CompanionSettingsPatch: Codable, Equatable, Sendable {
    public var bounds: Bounds?
    public var locked: Bool?
    public var alwaysOnTop: Bool?
    public var size: CompanionSizeMode?

    init(bounds: Bounds? = nil, locked: Bool? = nil, alwaysOnTop: Bool? = nil, size: CompanionSizeMode? = nil) {
        self.bounds = bounds
        self.locked = locked
        self.alwaysOnTop = alwaysOnTop
        self.size = size
    }

    init(_ settings: CompanionSettings) {
        self.init(
            bounds: settings.bounds,
            locked: settings.locked,
            alwaysOnTop: settings.alwaysOnTop,
            size: settings.size
        )
    }
}

public struct OnboardingSettings: Codable, Equatable, Sendable {
    public var completed: Bool

    public static let `default` = OnboardingSettings(completed: false)

    public init(completed: Bool) {
        self.completed = completed
    }
}

public struct OnboardingSettingsPatch: Codable, Equatable, Sendable {
    public var completed: Bool?

    init(completed: Bool? = nil) {
        self.completed = completed
    }

    init(_ settings: OnboardingSettings) {
        self.init(completed: settings.completed)
    }
}

func normalizeOnboardingSettings(_ patch: OnboardingSettingsPatch?, base: OnboardingSettings) -> OnboardingSettings {
    OnboardingSettings(completed: patch?.completed ?? base.completed)
}

public struct UsageAppConfig: Equatable, Sendable {
    public var id: String
    public var label: String
    public var ccusageCommand: String
    public var visibleByDefault: Bool

    public init(id: String, label: String, ccusageCommand: String, visibleByDefault: Bool) {
        self.id = id
        self.label = label
        self.ccusageCommand = ccusageCommand
        self.visibleByDefault = visibleByDefault
    }
}

enum UsageAppCatalog {
    static let supported: [UsageAppConfig] = [
        UsageAppConfig(id: "claude", label: "Claude Code", ccusageCommand: "claude", visibleByDefault: true),
        UsageAppConfig(id: "codex", label: "codex", ccusageCommand: "codex", visibleByDefault: true),
        UsageAppConfig(id: "opencode", label: "opencode", ccusageCommand: "opencode", visibleByDefault: true),
        UsageAppConfig(id: "amp", label: "amp", ccusageCommand: "amp", visibleByDefault: false),
        UsageAppConfig(id: "droid", label: "droid", ccusageCommand: "droid", visibleByDefault: false),
        UsageAppConfig(id: "codebuff", label: "codebuff", ccusageCommand: "codebuff", visibleByDefault: false),
        UsageAppConfig(id: "hermes", label: "hermes", ccusageCommand: "hermes", visibleByDefault: true),
        UsageAppConfig(id: "pi", label: "pi", ccusageCommand: "pi", visibleByDefault: false),
        UsageAppConfig(id: "goose", label: "goose", ccusageCommand: "goose", visibleByDefault: false),
        UsageAppConfig(id: "kilo", label: "kilo", ccusageCommand: "kilo", visibleByDefault: false),
        UsageAppConfig(id: "copilot", label: "copilot", ccusageCommand: "copilot", visibleByDefault: false),
        UsageAppConfig(id: "gemini", label: "gemini", ccusageCommand: "gemini", visibleByDefault: false),
        UsageAppConfig(id: "kimi", label: "kimi", ccusageCommand: "kimi", visibleByDefault: false),
        UsageAppConfig(id: "qwen", label: "qwen", ccusageCommand: "qwen", visibleByDefault: false),
        UsageAppConfig(id: "openclaw", label: "openclaw", ccusageCommand: "openclaw", visibleByDefault: true)
    ]
}

func orderedUsageApps() -> [UsageAppConfig] {
    let pinned = ["claude", "codex", "openclaw", "hermes", "opencode"]
    let pinnedApps = pinned.compactMap { id in UsageAppCatalog.supported.first { $0.id == id } }
    let pinnedIds = Set(pinnedApps.map(\.id))
    let rest = UsageAppCatalog.supported
        .filter { !pinnedIds.contains($0.id) }
        .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    return pinnedApps + rest
}

public struct TokeyPalSettings: Codable, Equatable, Sendable {
    public var appearance: AppearanceSettings
    public var polling: PollingSettings
    public var usageApps: [String: Bool]
    public var usageAppDirectories: [String: [String]]
    public var blindBoxThresholds: BlindBoxThresholds
    public var companion: CompanionSettings
    public var onboarding: OnboardingSettings

    public static let `default` = TokeyPalSettings(
        appearance: .default,
        polling: .default,
        usageApps: normalizeUsageAppSettings(nil),
        usageAppDirectories: normalizeUsageAppDirectories(nil),
        blindBoxThresholds: .default,
        companion: .default,
        onboarding: .default
    )
}

public struct TokeyPalSettingsUpdate: Codable, Equatable, Sendable {
    public var appearance: AppearanceSettings?
    public var polling: PollingSettingsPatch?
    public var usageApps: [String: Bool]?
    public var usageAppDirectories: [String: [String]]?
    public var blindBoxThresholds: BlindBoxThresholdsPatch?
    public var skinThresholds: BlindBoxThresholdsPatch?
    public var companion: CompanionSettingsPatch?
    public var onboarding: OnboardingSettingsPatch?

    public init(
        appearance: AppearanceSettings? = nil,
        polling: PollingSettings? = nil,
        usageApps: [String: Bool]? = nil,
        usageAppDirectories: [String: [String]]? = nil,
        blindBoxThresholds: BlindBoxThresholds? = nil,
        skinThresholds: BlindBoxThresholds? = nil,
        companion: CompanionSettings? = nil,
        onboarding: OnboardingSettings? = nil
    ) {
        self.appearance = appearance
        self.polling = polling.map(PollingSettingsPatch.init)
        self.usageApps = usageApps
        self.usageAppDirectories = usageAppDirectories
        self.blindBoxThresholds = blindBoxThresholds.map(BlindBoxThresholdsPatch.init)
        self.skinThresholds = skinThresholds.map(BlindBoxThresholdsPatch.init)
        self.companion = companion.map(CompanionSettingsPatch.init)
        self.onboarding = onboarding.map(OnboardingSettingsPatch.init)
    }
}

func normalizeUsageAppSettings(_ settings: [String: Bool]?) -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: UsageAppCatalog.supported.map { app in
        let value = app.visibleByDefault ? (settings?[app.id] ?? true) : false
        return (app.id, value)
    })
}

func normalizeUsageAppDirectories(_ settings: [String: [String]]?) -> [String: [String]] {
    Dictionary(uniqueKeysWithValues: UsageAppCatalog.supported.map { app in
        let values = (settings?[app.id] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return (app.id, values)
    })
}

func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
    Swift.min(Swift.max(value, minimum), maximum)
}
