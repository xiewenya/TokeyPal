import Observation
import TokeyPalNative

@MainActor
@Observable
final class CollectionViewModel {
    private(set) var view: BlindBoxView?
    var errorMessage: String?
    var selectedDetailCardId: String?

    private let settingsStore: SettingsStore
    private let usageService: UsageService
    private let companionRuntime: CompanionRuntime

    init(
        settingsStore: SettingsStore,
        usageService: UsageService,
        companionRuntime: CompanionRuntime
    ) {
        self.settingsStore = settingsStore
        self.usageService = usageService
        self.companionRuntime = companionRuntime
    }

    var cards: [CollectionCardView] { view?.collection ?? [] }
    var blindBoxModeEnabled: Bool { view?.currentMode.blindBoxModeEnabled ?? true }
    var deckBackUrl: String { view?.deckBackUrl ?? "" }

    func load() {
        do {
            let settings = try settingsStore.read()
            let stats = try usageService.cachedStats(settings: settings)
            view = try companionRuntime.buildBlindBoxView(todayTokens: stats.totals.todayTokens, settings: settings)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load blind box."
        }
    }

    func setBlindBoxMode(_ enabled: Bool) {
        companionRuntime.setBlindBoxMode(enabled)
        load()
    }

    func select(cardId: String) {
        do {
            try companionRuntime.selectCharacter(cardId)
            selectedDetailCardId = nil
            load()
        } catch {
            errorMessage = "Failed to select this card."
        }
    }
}
