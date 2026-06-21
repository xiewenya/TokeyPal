import Testing
@testable import TokeyPalNative

@Test func autoOpensOnboardingWhenNotCompleted() {
    var settings = TokeyPalSettings.default
    settings.onboarding = OnboardingSettings(completed: false)

    #expect(shouldAutoOpenOnboarding(settings) == true)
}

@Test func doesNotAutoOpenOnboardingWhenCompleted() {
    var settings = TokeyPalSettings.default
    settings.onboarding = OnboardingSettings(completed: true)

    #expect(shouldAutoOpenOnboarding(settings) == false)
}
