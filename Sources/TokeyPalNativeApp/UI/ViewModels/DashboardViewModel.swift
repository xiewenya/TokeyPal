import Observation
import TokeyPalNative

/// Dashboard 页数据:用量统计 + 当前盲盒视图,读取自现有服务。
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var stats: UsageStats?
    private(set) var blindBox: BlindBoxView?
    private(set) var errorMessage: String?

    private let settingsStore: SettingsStore
    private let usageService: UsageService
    private let companionRuntime: CompanionRuntime

    init(settingsStore: SettingsStore, usageService: UsageService, companionRuntime: CompanionRuntime) {
        self.settingsStore = settingsStore
        self.usageService = usageService
        self.companionRuntime = companionRuntime
    }

    var enabledApps: [UsageAppStats] {
        stats?.apps.filter { $0.enabled } ?? []
    }

    func load() {
        do {
            let settings = try settingsStore.read()
            let stats = try usageService.cachedStats(settings: settings)
            self.stats = stats
            self.blindBox = try? companionRuntime.buildBlindBoxView(
                todayTokens: stats.totals.todayTokens,
                settings: settings
            )
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load usage stats."
        }
    }
}
