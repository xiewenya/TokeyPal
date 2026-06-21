import SwiftUI

/// 还原 .game-header:眼眉 + 大标题,右侧可选配件。
struct GameHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    init(title: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("The daily blind box for vibe coders")
                    .font(ThemeFont.eyebrow)
                    .tracking(0.11 * 11)
                    .foregroundStyle(ThemeColor.primaryStrong)
                    .textCase(.uppercase)
                Text(title)
                    .font(ThemeFont.largeTitle)
                    .tracking(-0.045 * 42)
                    .foregroundStyle(ThemeColor.onSurface)
            }
            // 配件占满剩余宽度,内部用弹性 Spacer 控制间距(避免与外层 Spacer 竞争导致间距翻倍)。
            accessory()
                .frame(maxWidth: .infinity)
        }
        .frame(minHeight: ThemeMetric.headerHeight, alignment: .center)
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 6, trailing: 20))
    }
}
