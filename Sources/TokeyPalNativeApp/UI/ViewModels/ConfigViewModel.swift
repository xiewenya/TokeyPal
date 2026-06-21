import Observation
import TokeyPalNative

struct UsageSourceRowModel: Identifiable {
    let id: String
    let label: String
    let enabled: Bool
}

@MainActor
@Observable
final class ConfigViewModel {
    private(set) var settings: TokeyPalSettings
    var detectionResults: [String: UsageAppDetectionResult] = [:]
    var detectingApps: Set<String> = []
    var appErrors: [String: String] = [:]
    var configuringAppId: String?
    var directoryInputs: [String: String] = [:]
    var saved = false
    var generalError: String?

    private let settingsStore: SettingsStore
    private let detector: UsageAppDetector
    private let onChange: (TokeyPalSettings) -> Void

    init(settingsStore: SettingsStore, detector: UsageAppDetector, onChange: @escaping (TokeyPalSettings) -> Void) {
        self.settingsStore = settingsStore
        self.detector = detector
        self.onChange = onChange
        self.settings = (try? settingsStore.read()) ?? .default
    }

    var sources: [UsageSourceRowModel] {
        visibleUsageApps().map { app in
            UsageSourceRowModel(id: app.id, label: app.label, enabled: settings.usageApps[app.id] ?? false)
        }
    }

    // MARK: - 表单读值
    var idleSeconds: Int { secondsFromMs(settings.polling.idlePollingIntervalMs) }
    var activeSeconds: Int { secondsFromMs(settings.polling.activePollingIntervalMs) }
    var activeWindowMinutes: Int { minutesFromMs(settings.polling.activeWindowMs) }
    var stage2: Int { settings.blindBoxThresholds.stage2TokenThreshold }
    var stage3: Int { settings.blindBoxThresholds.stage3TokenThreshold }
    var stage4: Int { settings.blindBoxThresholds.stage4TokenThreshold }
    var alwaysOnTop: Bool { settings.companion.alwaysOnTop }
    var size: CompanionSizeMode { settings.companion.size }

    func defaultDirectoryInput(for id: String) -> String {
        defaultUsageDirectories(for: id).joined(separator: ", ")
    }

    func load() {
        settings = (try? settingsStore.read()) ?? .default
        directoryInputs = Dictionary(uniqueKeysWithValues: visibleUsageApps().map { app in
            let dirs = settings.usageAppDirectories[app.id] ?? []
            return (app.id, dirs.isEmpty ? defaultDirectoryInput(for: app.id) : dirs.joined(separator: ", "))
        })
        for app in visibleUsageApps() {
            detect(app.id, directories: settings.usageAppDirectories[app.id] ?? [])
        }
    }

    // MARK: - 来源
    func toggleSource(_ id: String, enabled: Bool) {
        appErrors[id] = nil
        if enabled, detectionResults[id]?.status != "detected" {
            openDirectoryConfig(id)
            return
        }
        apply(TokeyPalSettingsUpdate(usageApps: [id: enabled]))
    }

    func openDirectoryConfig(_ id: String) {
        if (directoryInputs[id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            directoryInputs[id] = defaultDirectoryInput(for: id)
        }
        configuringAppId = id
        detect(id, directories: parseDirectories(directoryInputs[id] ?? ""))
    }

    func closeDirectoryConfig() { configuringAppId = nil }

    func changeDirectoryInput(_ id: String, _ value: String) {
        directoryInputs[id] = value
        detectionResults[id] = nil
        appErrors[id] = nil
    }

    func saveDirectories(_ id: String) {
        let dirs = parseDirectories(directoryInputs[id] ?? "")
        detect(id, directories: dirs)
        guard detectionResults[id]?.status == "detected" else {
            appErrors[id] = "Directory check did not pass, so this directory was not saved."
            return
        }
        apply(TokeyPalSettingsUpdate(usageApps: [id: true], usageAppDirectories: [id: dirs]))
        appErrors[id] = nil
        configuringAppId = nil
    }

    // MARK: - 盲盒 / 轮询
    func setAlwaysOnTop(_ value: Bool) {
        apply(TokeyPalSettingsUpdate(companion: companion(alwaysOnTop: value)))
    }

    func setSize(_ value: CompanionSizeMode) {
        apply(TokeyPalSettingsUpdate(companion: companion(size: value)))
    }

    func updateIdleSeconds(_ s: Int) {
        apply(TokeyPalSettingsUpdate(polling: polling(idleMs: msFromSeconds(s))))
    }

    func updateActiveSeconds(_ s: Int) {
        apply(TokeyPalSettingsUpdate(polling: polling(activeMs: msFromSeconds(s))))
    }

    func updateActiveWindowMinutes(_ m: Int) {
        apply(TokeyPalSettingsUpdate(polling: polling(windowMs: msFromMinutes(m))))
    }

    func updateThresholds(stage2: Int, stage3: Int, stage4: Int) {
        apply(TokeyPalSettingsUpdate(blindBoxThresholds: BlindBoxThresholds(
            stage2TokenThreshold: stage2,
            stage3TokenThreshold: stage3,
            stage4TokenThreshold: stage4
        )))
    }

    // MARK: - 私有
    private func detect(_ id: String, directories: [String]) {
        detectingApps.insert(id)
        let result = detector.detect(appId: id, customDirectories: directories)
        detectionResults[id] = result
        detectingApps.remove(id)
    }

    private func apply(_ update: TokeyPalSettingsUpdate) {
        do {
            let next = try settingsStore.update(update)
            settings = next
            onChange(next)
            flashSaved()
        } catch {
            generalError = "Failed to save settings. Try again."
        }
    }

    private func flashSaved() {
        saved = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1600))
            saved = false
        }
    }

    private func parseDirectories(_ input: String) -> [String] {
        input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func companion(alwaysOnTop: Bool? = nil, size: CompanionSizeMode? = nil) -> CompanionSettings {
        CompanionSettings(
            bounds: settings.companion.bounds,
            locked: settings.companion.locked,
            alwaysOnTop: alwaysOnTop ?? settings.companion.alwaysOnTop,
            size: size ?? settings.companion.size
        )
    }

    private func polling(idleMs: Int? = nil, activeMs: Int? = nil, windowMs: Int? = nil) -> PollingSettings {
        PollingSettings(
            idlePollingIntervalMs: idleMs ?? settings.polling.idlePollingIntervalMs,
            activePollingIntervalMs: activeMs ?? settings.polling.activePollingIntervalMs,
            activeWindowMs: windowMs ?? settings.polling.activeWindowMs
        )
    }
}
