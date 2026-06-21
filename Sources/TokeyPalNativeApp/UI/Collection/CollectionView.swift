import SwiftUI
import TokeyPalNative

struct CollectionView: View {
    @Bindable var viewModel: CollectionViewModel

    var body: some View {
        Group {
            if let error = viewModel.errorMessage, viewModel.view == nil {
                GameStatusMessage(text: error, isError: true)
            } else {
                GamePanel {
                    VStack(spacing: 0) {
                        headingRow
                        CollectionGrid(
                            cards: viewModel.cards,
                            deckBackUrl: viewModel.deckBackUrl,
                            onTap: { viewModel.selectedDetailCardId = $0 }
                        )
                    }
                }
            }
        }
        .onAppear { viewModel.load() }
        .overlay { detailOverlay }
    }

    private var headingRow: some View {
        HStack {
            Text("COLLECTION")
                .font(ThemeFont.panelHeading).tracking(0.11 * 11)
                .foregroundStyle(ThemeColor.primaryStrong)
            Spacer()
            Text("\(viewModel.cards.count) Cards")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ThemeColor.primaryStrong)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(ThemeColor.primaryStrong.opacity(0.12)))
            HStack(spacing: 10) {
                Text("Blind Box Mode")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ThemeColor.onMuted)
                NativeSwitch(isOn: Binding(
                    get: { viewModel.blindBoxModeEnabled },
                    set: { viewModel.setBlindBoxMode($0) }
                ))
            }
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
    }

    @ViewBuilder
    private var detailOverlay: some View {
        if let id = viewModel.selectedDetailCardId,
           let card = viewModel.cards.first(where: { $0.id == id }) {
            let canSelect = canSelectCollectionCard(blindBoxModeEnabled: viewModel.blindBoxModeEnabled, selectable: card.selectable)
            CardDetailDialog(
                card: card,
                blindBoxModeEnabled: viewModel.blindBoxModeEnabled,
                deckBackUrl: viewModel.deckBackUrl,
                onClose: { viewModel.selectedDetailCardId = nil },
                onSelect: canSelect ? { viewModel.select(cardId: card.id) } : nil
            )
        }
    }
}
