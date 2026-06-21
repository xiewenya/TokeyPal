import SwiftUI
import TokeyPalNative

/// Dashboard 页正文:当前阶段卡 + 单应用用量表。
struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 18) {
            if let message = viewModel.errorMessage {
                GameStatusMessage(text: message, isError: true)
            }
            if let blindBox = viewModel.blindBox {
                GamePanel(title: "CURRENT STAGE") {
                    StageBoard(view: blindBox).padding(.top, 4)
                }
            }
            if let stats = viewModel.stats {
                GamePanel(title: "PER-APP USAGE") {
                    UsageTable(stats: stats)
                }
            } else if viewModel.errorMessage == nil {
                GameStatusMessage(text: "Loading usage stats…")
            }
        }
        .onAppear { viewModel.load() }
    }
}

/// 标题右侧的用量汇总配件(有 stats 时显示)。
struct DashboardSummaryAccessory: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        if let stats = viewModel.stats {
            DashboardSummary(stats: stats)
        }
    }
}
