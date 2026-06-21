import Foundation

/// Returns true when the first-run onboarding flow should be shown automatically
/// at app launch (i.e. the user has not completed or skipped onboarding yet).
public func shouldAutoOpenOnboarding(_ settings: TokeyPalSettings) -> Bool {
    !settings.onboarding.completed
}
