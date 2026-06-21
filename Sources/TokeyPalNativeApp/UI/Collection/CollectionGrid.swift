import SwiftUI
import TokeyPalNative

/// 4 列收藏卡网格。
struct CollectionGrid: View {
    let cards: [CollectionCardView]
    let deckBackUrl: String
    let onTap: (String) -> Void

    /// 驱动当前选中卡片的悬浮微动。
    @State private var floating = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cards, id: \.id) { card in
                Button { onTap(card.id) } label: {
                    ZStack(alignment: .bottom) {
                        CardMedia(card: card, deckBackUrl: deckBackUrl)
                            .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        Text(card.name)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(ThemeColor.onSurface)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#fffaf1").opacity(0.86)))
                            .padding(8)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(strokeColor(card), lineWidth: card.downloadFailed || card.selected ? 2 : 0)
                    )
                    // 选中卡片:静态柔光高亮 + 与 Dashboard 一致的纵向悬浮微动。
                    .shadow(color: Color(hex: "#f3b23f").opacity(card.selected ? 0.24 : 0), radius: 14, y: 8)
                    .offset(y: card.selected && floating ? -7 : 0)
                    .animation(
                        card.selected
                            ? .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
                            : .default,
                        value: floating
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .onAppear { floating = true }
    }

    private func strokeColor(_ card: CollectionCardView) -> Color {
        if card.downloadFailed { return ThemeColor.error }
        if card.selected { return Color(hex: "#f3b23f").opacity(0.76) }
        return Color.clear
    }
}
