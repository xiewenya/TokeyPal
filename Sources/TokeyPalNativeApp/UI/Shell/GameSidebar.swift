import SwiftUI
import TokeyPalNative

/// 还原 .game-sidebar:品牌行 + 纵向导航,选中态红底白字。
struct GameSidebar: View {
    let selected: DashboardTab
    let onSelect: (DashboardTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                brandLogo
                    .frame(width: 34, height: 34)
                Text("TokeyPal")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(ThemeColor.onSurface)
            }
            .frame(minHeight: 36, alignment: .leading)
            .padding(.bottom, 24)

            VStack(spacing: 16) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    navButton(tab)
                }
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 24, leading: 18, bottom: 24, trailing: 18))
        .frame(width: ThemeMetric.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.74))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(.sRGB, red: 89.0 / 255.0, green: 59.0 / 255.0, blue: 33.0 / 255.0, opacity: 0.12))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var brandLogo: some View {
        if let logo = BundleImage.load("tokey-logo") {
            Image(nsImage: logo).resizable().scaledToFit()
        } else {
            Image(systemName: "sparkles").resizable().scaledToFit()
        }
    }

    @ViewBuilder
    private func navButton(_ tab: DashboardTab) -> some View {
        let active = tab == selected
        Button {
            onSelect(tab)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: tab.navIconSystemName)
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 22, height: 22, alignment: .center)
                Text(tab.navTitle)
                    .font(.system(size: 14, weight: .heavy))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .foregroundStyle(active ? Color.white : ThemeColor.onMuted)
            .background(
                RoundedRectangle(cornerRadius: ThemeMetric.navCornerRadius)
                    .fill(active ? Color(hex: "#ef5a50") : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
