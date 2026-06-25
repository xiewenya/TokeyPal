public enum CompanionStageDecision: Equatable, Sendable {
    case initialize(stage: Int)
    case evolve(toStage: Int)
    case downgrade(toStage: Int)
    case unchanged(stage: Int)
}

public enum CompanionStageCoordinator {
    public static func decision(displayedStage: Int?, desiredStage: Int) -> CompanionStageDecision {
        let desiredStage = clampStage(desiredStage)
        guard let displayedStage else {
            return .initialize(stage: desiredStage)
        }
        let current = clampStage(displayedStage)
        if current < desiredStage {
            return .evolve(toStage: current + 1)
        }
        if current > desiredStage {
            return .downgrade(toStage: desiredStage)
        }
        return .unchanged(stage: current)
    }
}

public func companionUsageAffectingSettingsChanged(from old: TokeyPalSettings, to new: TokeyPalSettings) -> Bool {
    old.usageApps != new.usageApps ||
        old.usageAppDirectories != new.usageAppDirectories ||
        old.blindBoxThresholds != new.blindBoxThresholds
}

private func clampStage(_ stage: Int) -> Int {
    max(1, min(stage, 4))
}
