import Foundation

public enum CompanionInteractionEffect: Equatable, Sendable {
    case playAction(String)
    case clearAction
}

public struct CompanionInteraction: Equatable, Sendable {
    public private(set) var currentAction: String?

    public init(currentAction: String? = nil) {
        self.currentAction = currentAction
    }

    public mutating func trigger(_ action: String) -> CompanionInteractionEffect? {
        guard ["idle", "hover", "click", "evolve"].contains(action) else {
            return nil
        }
        guard canStart(action) else {
            return nil
        }
        currentAction = action
        return .playAction(action)
    }

    public mutating func animationTimeout() -> CompanionInteractionEffect? {
        guard currentAction != nil else {
            return nil
        }
        currentAction = nil
        return .clearAction
    }

    private func canStart(_ action: String) -> Bool {
        guard let currentAction else {
            return true
        }
        return priority(action) > priority(currentAction)
    }
}

private func priority(_ action: String) -> Int {
    switch action {
    case "evolve":
        return 3
    case "hover", "click":
        return 2
    case "idle":
        return 1
    default:
        return 0
    }
}

public func formatCompanionTokenBubble(_ todayTokens: Int) -> String {
    "Today \(formatCompactTokens(max(0, todayTokens))) tokens"
}
