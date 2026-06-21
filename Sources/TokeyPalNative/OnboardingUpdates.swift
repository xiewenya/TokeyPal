import Foundation

/// 首启可见来源(与 Config 列表一致)。
public let onboardingVisibleAppIds: [String] = ["claude", "codex", "openclaw", "hermes", "opencode"]

/// 仅标记 onboarding 完成。
public func onboardingCompletedUpdate() -> TokeyPalSettingsUpdate {
    TokeyPalSettingsUpdate(onboarding: OnboardingSettings(completed: true))
}

/// 跳过:关闭全部可见来源并标记完成。
public func onboardingSkipUpdate() -> TokeyPalSettingsUpdate {
    let disabled = Dictionary(uniqueKeysWithValues: onboardingVisibleAppIds.map { ($0, false) })
    return TokeyPalSettingsUpdate(usageApps: disabled, onboarding: OnboardingSettings(completed: true))
}
