import SwiftUI
import TokeyPalNative

/// 收藏卡详情弹窗:4 阶段卡 + 选择 / 提示。
struct CardDetailDialog: View {
    let card: CollectionCardView
    let blindBoxModeEnabled: Bool
    let deckBackUrl: String
    let onClose: () -> Void
    let onSelect: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                HStack {
                    Text(card.name).font(.system(size: 14, weight: .black)).foregroundStyle(ThemeColor.primaryStrong)
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)) }
                        .buttonStyle(.plain).foregroundStyle(ThemeColor.onMuted)
                }
                .padding(.horizontal, 18).frame(minHeight: 50)
                Divider().overlay(ThemeColor.outlineSoft)

                HStack(alignment: .top, spacing: 12) {
                    ForEach(card.stageCards, id: \.stage) { stageCard in
                        VStack(spacing: 8) {
                            Text(stageLabel(stageCard.stage))
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(ThemeColor.onMuted)
                            CardMedia(stageCard: stageCard, deckBackUrl: deckBackUrl)
                                .aspectRatio(1.0 / 2.0, contentMode: .fit)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)

                Divider().overlay(ThemeColor.outlineSoft)
                HStack {
                    Spacer()
                    if let onSelect {
                        Button("Select Card", action: onSelect)
                            .buttonStyle(.plain).font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14).frame(minHeight: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.surfaceHigh))
                    } else {
                        Text(blindBoxModeEnabled ? "Selection is disabled in Blind Box Mode." : "Unlock this card before selecting.")
                            .font(.system(size: 12)).foregroundStyle(ThemeColor.onMuted)
                    }
                }
                .padding(.horizontal, 18).frame(minHeight: 52)
            }
            .frame(width: 820)
            .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemeColor.outlineSoft, lineWidth: 1))
            .padding(28)
        }
    }
}
