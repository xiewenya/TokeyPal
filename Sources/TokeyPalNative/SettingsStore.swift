import Foundation

public struct SettingsStore: Sendable {
    public let settingsURL: URL

    public init(settingsURL: URL) {
        self.settingsURL = settingsURL
    }

    public func read() throws -> TokeyPalSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            let update = try JSONDecoder().decode(TokeyPalSettingsUpdate.self, from: data)
            return normalizeSettings(update: update, base: .default)
        } catch {
            return .default
        }
    }

    @discardableResult
    public func update(_ update: TokeyPalSettingsUpdate) throws -> TokeyPalSettings {
        let current = try read()
        let next = normalizeSettings(update: update, base: current)
        let directory = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(next)
        try data.write(to: settingsURL, options: .atomic)
        return next
    }
}

private func normalizeSettings(update: TokeyPalSettingsUpdate, base: TokeyPalSettings) -> TokeyPalSettings {
    var next = base

    if let appearance = update.appearance {
        next.appearance = AppearanceSettings(theme: ThemeMode.normalized(appearance.theme))
    }

    if let polling = update.polling {
        next.polling = PollingSettings(
            idlePollingIntervalMs: polling.idlePollingIntervalMs ?? next.polling.idlePollingIntervalMs,
            activePollingIntervalMs: polling.activePollingIntervalMs ?? next.polling.activePollingIntervalMs,
            activeWindowMs: polling.activeWindowMs ?? next.polling.activeWindowMs
        ).normalized()
    } else {
        next.polling = next.polling.normalized()
    }

    if let usageApps = update.usageApps {
        var merged = next.usageApps
        for (id, enabled) in usageApps {
            merged[id] = enabled
        }
        next.usageApps = normalizeUsageAppSettings(merged)
    } else {
        next.usageApps = normalizeUsageAppSettings(next.usageApps)
    }

    if let directories = update.usageAppDirectories {
        var merged = next.usageAppDirectories
        for (id, values) in directories {
            merged[id] = values
        }
        next.usageAppDirectories = normalizeUsageAppDirectories(merged)
    } else {
        next.usageAppDirectories = normalizeUsageAppDirectories(next.usageAppDirectories)
    }

    let thresholdPatch = mergedThresholdPatch(update.blindBoxThresholds, update.skinThresholds)
    if let thresholdPatch {
        next.blindBoxThresholds = BlindBoxThresholds(
            stage2TokenThreshold: thresholdPatch.stage2TokenThreshold ?? thresholdPatch.starter ?? next.blindBoxThresholds.stage2TokenThreshold,
            stage3TokenThreshold: thresholdPatch.stage3TokenThreshold ?? thresholdPatch.high ?? next.blindBoxThresholds.stage3TokenThreshold,
            stage4TokenThreshold: thresholdPatch.stage4TokenThreshold ?? thresholdPatch.ultimate ?? next.blindBoxThresholds.stage4TokenThreshold
        ).normalized()
    } else {
        next.blindBoxThresholds = next.blindBoxThresholds.normalized()
    }

    if let companion = update.companion {
        next.companion = CompanionSettings(
            bounds: companion.bounds ?? next.companion.bounds,
            locked: companion.locked ?? next.companion.locked,
            alwaysOnTop: companion.alwaysOnTop ?? next.companion.alwaysOnTop,
            size: companion.size ?? next.companion.size
        ).normalized()
    } else {
        next.companion = next.companion.normalized()
    }

    next.onboarding = normalizeOnboardingSettings(update.onboarding, base: next.onboarding)

    return next
}

private func mergedThresholdPatch(
    _ current: BlindBoxThresholdsPatch?,
    _ legacy: BlindBoxThresholdsPatch?
) -> BlindBoxThresholdsPatch? {
    guard current != nil || legacy != nil else {
        return nil
    }

    return BlindBoxThresholdsPatch(
        stage2TokenThreshold: current?.stage2TokenThreshold ?? legacy?.stage2TokenThreshold ?? legacy?.starter,
        stage3TokenThreshold: current?.stage3TokenThreshold ?? legacy?.stage3TokenThreshold ?? legacy?.high,
        stage4TokenThreshold: current?.stage4TokenThreshold ?? legacy?.stage4TokenThreshold ?? legacy?.ultimate
    )
}
