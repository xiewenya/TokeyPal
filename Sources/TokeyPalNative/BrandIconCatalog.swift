import Foundation

/// 单个品牌图标的资源规格。彩色图标 isMono=false,直接渲染;
/// 单色图标 isMono=true,需在圆角底色上以模板色渲染字形。
public struct BrandIconSpec: Equatable, Sendable {
    public let assetName: String
    public let isMono: Bool
    public let avatarBackgroundHex: String?
    public let avatarForegroundHex: String?

    public init(
        assetName: String,
        isMono: Bool,
        avatarBackgroundHex: String? = nil,
        avatarForegroundHex: String? = nil
    ) {
        self.assetName = assetName
        self.isMono = isMono
        self.avatarBackgroundHex = avatarBackgroundHex
        self.avatarForegroundHex = avatarForegroundHex
    }
}

/// appId → 品牌图标资源映射。资源由 Dashboard/scripts/extract-brand-icons.mjs
/// 从 @lobehub/icons 提取,命名为 brand-<appId>,无专属图标时回退 brand-lobehub。
public enum BrandIconCatalog {
    public static let fallbackAssetName = "brand-lobehub"
    public static let visibleAppIds: [String] = ["claude", "codex", "openclaw", "hermes", "opencode"]

    public static func spec(for appId: String) -> BrandIconSpec {
        switch appId {
        case "claude":
            return BrandIconSpec(assetName: "brand-claude", isMono: false)
        case "codex":
            return BrandIconSpec(assetName: "brand-codex", isMono: false)
        case "openclaw":
            return BrandIconSpec(assetName: "brand-openclaw", isMono: false)
        case "hermes":
            return BrandIconSpec(
                assetName: "brand-hermes",
                isMono: true,
                avatarBackgroundHex: "#ffffff",
                avatarForegroundHex: "#000000"
            )
        case "opencode":
            return BrandIconSpec(
                assetName: "brand-opencode",
                isMono: true,
                avatarBackgroundHex: "#000000",
                avatarForegroundHex: "#ffffff"
            )
        default:
            return BrandIconSpec(assetName: fallbackAssetName, isMono: false)
        }
    }
}
