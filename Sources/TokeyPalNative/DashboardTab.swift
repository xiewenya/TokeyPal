import Foundation

/// Dashboard 窗口的四个主 Tab。rawValue 与托盘 / 旧 JS 导航 id 对齐。
public enum DashboardTab: String, CaseIterable, Sendable {
    case dashboard
    case blindBox
    case config

    public var headerTitle: String {
        switch self {
        case .dashboard: return "DASHBOARD"
        case .blindBox: return "COLLECTIONS"
        case .config: return "CONFIG"
        }
    }

    public var navTitle: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .blindBox: return "Collections"
        case .config: return "Config"
        }
    }

    public var navIconSystemName: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .blindBox: return "gift"
        case .config: return "gearshape"
        }
    }
}
