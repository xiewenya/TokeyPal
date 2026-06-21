import SwiftUI
import TokeyPalNative

/// 原生 Dashboard 根视图:固定 1120×748 圆角窗 + 侧栏 + 标题 + 内容区。
/// Dashboard 页已实现;其它 Tab 暂为占位,后续块替换。
struct RootView: View {
    @Bindable var store: AppStore
    @State private var dashboardVM: DashboardViewModel
    @State private var configVM: ConfigViewModel
    @State private var collectionVM: CollectionViewModel
    @State private var onboardingVM: OnboardingViewModel

    init(store: AppStore) {
        self.store = store
        _dashboardVM = State(initialValue: store.makeDashboardViewModel())
        _configVM = State(initialValue: store.makeConfigViewModel())
        _collectionVM = State(initialValue: store.makeCollectionViewModel())
        _onboardingVM = State(initialValue: store.makeOnboardingViewModel())
    }

    var body: some View {
        ZStack {
            if store.onboardingCompleted {
                shell
            } else {
                OnboardingView(viewModel: onboardingVM)
                    .frame(width: ThemeMetric.windowWidth, height: ThemeMetric.windowHeight)
                    .background(ThemeColor.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeMetric.windowCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeMetric.windowCornerRadius)
                            .stroke(Color(.sRGB, red: 89.0 / 255.0, green: 59.0 / 255.0, blue: 33.0 / 255.0, opacity: 0.12), lineWidth: 1)
                    )
            }
        }
        .preferredColorScheme(.light)
    }

    private var shell: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#fef6ec"), Color.white, Color(hex: "#fef6ec")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                GameSidebar(selected: store.selectedTab) { store.select($0) }
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        content
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .scrollIndicators(.hidden)
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: ThemeMetric.windowWidth, height: ThemeMetric.windowHeight)
            .background(Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: ThemeMetric.windowCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeMetric.windowCornerRadius)
                    .stroke(Color(.sRGB, red: 89.0 / 255.0, green: 59.0 / 255.0, blue: 33.0 / 255.0, opacity: 0.12), lineWidth: 1)
            )
            .shadow(
                color: Color(.sRGB, red: 88.0 / 255.0, green: 56.0 / 255.0, blue: 25.0 / 255.0, opacity: 0.16),
                radius: 40,
                y: 34
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        if store.selectedTab == .dashboard {
            GameHeader(title: store.selectedTab.headerTitle) {
                DashboardSummaryAccessory(viewModel: dashboardVM)
            }
        } else {
            GameHeader(title: store.selectedTab.headerTitle)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.selectedTab {
        case .dashboard:
            DashboardView(viewModel: dashboardVM)
        case .config:
            ConfigView(viewModel: configVM)
        case .blindBox:
            CollectionView(viewModel: collectionVM)
        }
    }
}
