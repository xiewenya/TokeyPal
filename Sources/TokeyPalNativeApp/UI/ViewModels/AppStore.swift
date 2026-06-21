import Observation
import TokeyPalNative

/// 原生 Dashboard 的导航 / 全局状态。注入现有服务,供各页 ViewModel 复用。
@MainActor
@Observable
final class AppStore {
    var selectedTab: DashboardTab = .dashboard
    var onboardingCompleted: Bool

    let settingsStore: SettingsStore
    let usageService: UsageService
    let companionRuntime: CompanionRuntime
    let detector = UsageAppDetector()
    var settingsDidChange: ((TokeyPalSettings) -> Void)?

    init(
        settingsStore: SettingsStore,
        usageService: UsageService,
        companionRuntime: CompanionRuntime
    ) {
        self.settingsStore = settingsStore
        self.usageService = usageService
        self.companionRuntime = companionRuntime
        let settings = (try? settingsStore.read()) ?? .default
        self.onboardingCompleted = settings.onboarding.completed
    }

    func select(_ tab: DashboardTab) {
        selectedTab = tab
    }

    /// 供托盘菜单用字符串 id 切换(与旧 __tokeyPalNavigate 对齐)。
    func select(rawTab: String) {
        if let tab = DashboardTab(rawValue: rawTab) {
            selectedTab = tab
        }
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            settingsStore: settingsStore,
            usageService: usageService,
            companionRuntime: companionRuntime
        )
    }

    func makeConfigViewModel() -> ConfigViewModel {
        ConfigViewModel(
            settingsStore: settingsStore,
            detector: detector,
            onChange: { [weak self] settings in self?.settingsDidChange?(settings) }
        )
    }

    func makeCollectionViewModel() -> CollectionViewModel {
        CollectionViewModel(
            settingsStore: settingsStore,
            usageService: usageService,
            companionRuntime: companionRuntime
        )
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            settingsStore: settingsStore,
            detector: detector,
            onComplete: { [weak self] in self?.completeOnboarding() }
        )
    }

    func completeOnboarding() {
        onboardingCompleted = true
    }
}
