import SwiftUI
import TokeyPalNative

struct CardBack: View {
    let url: String?
    var body: some View { RemoteFileImage(urlString: url) }
}

struct CardLayers: View {
    let layers: [CardLayer]
    var body: some View {
        ZStack {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                RemoteFileImage(urlString: layer.url)
            }
        }
    }
}

/// 收藏卡 / 阶段卡媒体:有 layers 用叠层封面,否则卡背。
struct CardMedia: View {
    let layers: [CardLayer]?
    let backUrl: String?

    var body: some View {
        if let layers, !layers.isEmpty {
            CardLayers(layers: layers)
        } else {
            CardBack(url: backUrl)
        }
    }
}

extension CardMedia {
    init(stageCard: StageCard, deckBackUrl: String) {
        self.init(layers: stageCard.kind == "back" ? nil : stageCard.layers, backUrl: stageCard.kind == "back" ? stageCard.url : deckBackUrl)
    }
    init(card: CollectionCardView, deckBackUrl: String) {
        self.init(layers: card.layers, backUrl: deckBackUrl)
    }
}
