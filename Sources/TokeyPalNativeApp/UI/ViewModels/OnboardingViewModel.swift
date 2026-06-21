import Observation
import TokeyPalNative

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step { case detecting, sources, done }

    struct SourceRow: Identifiable {
        let id: String
        let label: String
        var enabled: Bool
        let detected: Bool
    }

    private(set) var step: Step = .detecting
    private(set) var sources: [SourceRow] = []
    var saving = false
    var errorMessage: String?

    private let settingsStore: SettingsStore
    private let detector: UsageAppDetector
    private let onComplete: () -> Void
    private var completed = false

    init(settingsStore: SettingsStore, detector: UsageAppDetector, onComplete: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.detector = detector
        self.onComplete = onComplete
    }

    func start() {
        let settings = (try? settingsStore.read()) ?? .default
        var rows: [SourceRow] = []
        for app in visibleUsageApps() {
            let dirs = settings.usageAppDirectories[app.id] ?? []
            let detected = detector.detect(appId: app.id, customDirectories: dirs).status == "detected"
            var enabled = settings.usageApps[app.id] ?? false
            if detected && !enabled {
                if (try? settingsStore.update(TokeyPalSettingsUpdate(usageApps: [app.id: true]))) != nil {
                    enabled = true
                }
            }
            rows.append(SourceRow(id: app.id, label: app.label, enabled: enabled, detected: detected))
        }
        sources = rows
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if step == .detecting { step = .sources }
        }
    }

    func toggle(_ id: String, enabled: Bool) {
        _ = try? settingsStore.update(TokeyPalSettingsUpdate(usageApps: [id: enabled]))
        if let index = sources.firstIndex(where: { $0.id == id }) {
            sources[index].enabled = enabled
        }
    }

    func finish(skip: Bool) {
        saving = true
        errorMessage = nil
        do {
            _ = try settingsStore.update(skip ? onboardingSkipUpdate() : onboardingCompletedUpdate())
            step = .done
        } catch {
            errorMessage = "Failed to save. Try again."
        }
        saving = false
    }

    func enterDashboard() {
        guard !completed else { return }
        completed = true
        onComplete()
    }
}
