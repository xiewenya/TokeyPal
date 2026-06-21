import SwiftUI
import TokeyPalNative

/// 用量来源 / 单应用表的品牌图标。彩色直接渲染;单色在品牌色圆角底上以模板色渲染。
struct BrandIcon: View {
    let appId: String
    var size: CGFloat = 28

    var body: some View {
        let spec = BrandIconCatalog.spec(for: appId)
        Group {
            if spec.isMono {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: spec.avatarBackgroundHex ?? "#111827"))
                    image(spec.assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(hex: spec.avatarForegroundHex ?? "#ffffff"))
                        .frame(width: size * 0.5, height: size * 0.5)
                }
            } else {
                image(spec.assetName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }

    private func image(_ name: String) -> Image {
        if let nsImage = BundleImage.load(name) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "app.dashed")
    }
}
