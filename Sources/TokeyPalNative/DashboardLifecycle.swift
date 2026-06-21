import Foundation

public enum DashboardLifecycleEffect: Equatable, Sendable {
    case createHidden
    case load
    case show
    case hide
    case scheduleDestroy
    case cancelDestroy
    case destroy
}

public struct DashboardLifecycle: Equatable, Sendable {
    public private(set) var isCreated: Bool
    public private(set) var isVisible: Bool
    public private(set) var isLoaded: Bool
    public private(set) var isReady: Bool
    public private(set) var isDestroyScheduled: Bool

    public init(
        isCreated: Bool = false,
        isVisible: Bool = false,
        isLoaded: Bool = false,
        isReady: Bool = false,
        isDestroyScheduled: Bool = false
    ) {
        self.isCreated = isCreated
        self.isVisible = isVisible
        self.isLoaded = isLoaded
        self.isReady = isReady
        self.isDestroyScheduled = isDestroyScheduled
    }

    public mutating func open() -> [DashboardLifecycleEffect] {
        var effects: [DashboardLifecycleEffect] = []
        if isDestroyScheduled {
            isDestroyScheduled = false
            effects.append(.cancelDestroy)
        }

        if !isCreated {
            isCreated = true
            isVisible = false
            isLoaded = false
            isReady = false
            effects.append(.createHidden)
        }

        if !isLoaded {
            isLoaded = true
            effects.append(.load)
            return effects
        }

        isVisible = true
        effects.append(.show)
        return effects
    }

    public mutating func ready() -> [DashboardLifecycleEffect] {
        guard isCreated else {
            return []
        }

        isReady = true
        isVisible = true
        return [.show]
    }

    public mutating func close() -> [DashboardLifecycleEffect] {
        guard isCreated else {
            return []
        }

        isVisible = false
        isDestroyScheduled = true
        return [.hide, .scheduleDestroy]
    }

    public mutating func idleTimeout() -> [DashboardLifecycleEffect] {
        guard isCreated, isDestroyScheduled, !isVisible else {
            return []
        }

        isCreated = false
        isVisible = false
        isLoaded = false
        isReady = false
        isDestroyScheduled = false
        return [.destroy]
    }
}
