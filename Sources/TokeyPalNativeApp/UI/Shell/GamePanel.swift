import SwiftUI

/// 还原 .game-panel:白渐变底 + outlineSoft 描边 + 阴影,可选红色大写小标题。
struct GamePanel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack {
                    Text(title)
                        .font(ThemeFont.panelHeading)
                        .tracking(0.11 * 11)
                        .foregroundStyle(ThemeColor.primaryStrong)
                        .textCase(.uppercase)
                    Spacer()
                }
                .frame(minHeight: 50)
                .padding(.horizontal, 20)
            }
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: ThemeMetric.panelCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.88), Color(hex: "#fffaf1").opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: ThemeMetric.panelCornerRadius).fill(ThemeColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeMetric.panelCornerRadius)
                        .stroke(ThemeColor.outlineSoft, lineWidth: 1)
                )
        )
        .shadow(
            color: Color(.sRGB, red: 88.0 / 255.0, green: 56.0 / 255.0, blue: 25.0 / 255.0, opacity: 0.08),
            radius: 19,
            y: 16
        )
    }
}
