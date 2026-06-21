import SwiftUI
import TokeyPalNative

/// 当前阶段卡:进度条 + 4 阶段标签 + 4 张阶段卡。
struct StageBoard: View {
    let view: BlindBoxView

    /// 驱动当前激活卡片的悬浮微动(上下轻浮 + 极轻微缩放)。
    @State private var floating = false

    var body: some View {
        VStack(spacing: 12) {
            progressBar
            HStack(spacing: 22) {
                ForEach(view.stageCards, id: \.stage) { card in
                    stageLabel(card)
                }
            }
            HStack(alignment: .top, spacing: 22) {
                ForEach(view.stageCards, id: \.stage) { card in
                    stageCard(card)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
        .onAppear { floating = true }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let count = max(1, view.stageCards.count)
            let gap: CGFloat = 22 // 与卡片行 HStack(spacing:) 一致
            let cardWidth = (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count)
            // 每张卡片的 x 轴中心
            let centers = (0..<count).map { CGFloat($0) * (cardWidth + gap) + cardWidth / 2 }
            let midY = geo.size.height / 2
            // 进度条走到“当前已激活的最后一个 stage 节点”,并按本阶段进度向下一个节点延伸。
            let fillWidth = progressFillWidth(centers: centers, fullWidth: geo.size.width)

            ZStack(alignment: .leading) {
                // 轨道:第一张卡片左边(0)→ 最后一张卡片右边(整宽)
                Capsule().fill(Color(hex: "#efe4d2").opacity(0.68)).frame(height: 10)
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#ef5a50"), Color(hex: "#f3b23f"), Color(hex: "#3bc9a0")],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: fillWidth, height: 10)
                    .animation(.easeInOut(duration: 0.5), value: fillWidth)
                // 节点:对齐到每张卡片的 x 轴中心
                ForEach(Array(view.stageMarkers.enumerated()), id: \.offset) { index, marker in
                    Circle()
                        .fill(marker.reached ? Color(hex: "#ef5a50") : Color(hex: "#efe4d2"))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .position(x: index < centers.count ? centers[index] : 0, y: midY)
                }
            }
        }
        .frame(height: 28)
    }

    /// 计算进度条填充宽度:对齐到当前激活节点,并按本阶段进度向下一个节点插值。
    private func progressFillWidth(centers: [CGFloat], fullWidth: CGFloat) -> CGFloat {
        guard !centers.isEmpty else { return 0 }
        guard let activeIdx = view.stageMarkers.lastIndex(where: { $0.reached }),
              activeIdx < centers.count else {
            return 0
        }
        let baseX = centers[activeIdx]
        let nextX = activeIdx + 1 < centers.count ? centers[activeIdx + 1] : fullWidth
        let frac = CGFloat(min(100, max(0, view.progressPercent))) / 100
        return baseX + (nextX - baseX) * frac
    }

    private func stageLabel(_ card: StageCard) -> some View {
        Text("Stage \(card.stage)")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(card.current ? Color.white : ThemeColor.onMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(Capsule().fill(card.current ? Color(hex: "#ef5a50") : Color(hex: "#efe4d2").opacity(0.72)))
    }

    private func stageCard(_ card: StageCard) -> some View {
        let urlString = card.kind == "back" ? card.url : card.layers?.first?.url
        let active = card.current
        return RemoteFileImage(urlString: urlString)
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0 / 2.0, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [Color.white, Color(hex: "#fffdf8")], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(card.current ? Color(hex: "#f3b23f").opacity(0.76) : ThemeColor.outlineSoft, lineWidth: card.current ? 2 : 1)
            )
            .opacity(card.kind == "back" && !card.current ? 0.72 : 1)
            // 静态柔光:让当前激活卡片更突出(不参与动画)。
            .shadow(color: Color(hex: "#f3b23f").opacity(active ? 0.24 : 0), radius: 14, y: 8)
            // 悬浮微动:对齐 tokey-landing 的 livelyFloat —— 纯纵向轻浮,无缩放。
            // translate3d(0,-7px,0) over 5.6s ease-in-out infinite(自动往返,每程 2.8s)。
            .offset(y: active && floating ? -7 : 0)
            .animation(
                active
                    ? .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
                    : .default,
                value: floating
            )
    }
}
