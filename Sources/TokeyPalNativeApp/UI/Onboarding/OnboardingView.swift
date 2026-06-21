import SwiftUI
import TokeyPalNative

/// 首启流程:左 Hero + 右三步内容(检测 / 选源 / 完成)。
struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                OnboardingHero(step: viewModel.step)
                    .frame(width: geo.size.width * 0.45)
                    .overlay(alignment: .trailing) { Rectangle().fill(ThemeColor.outlineSoft).frame(width: 1) }
                pane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(EdgeInsets(top: 28, leading: 30, bottom: 28, trailing: 30))
                    .background(ThemeColor.surfaceLow)
            }
        }
        .onAppear { viewModel.start() }
    }

    @ViewBuilder
    private var pane: some View {
        switch viewModel.step {
        case .detecting: detectingPane
        case .sources: sourcesPane
        case .done: donePane
        }
    }

    private var detectingPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("The daily blind box for vibe coders")
            Text("Getting set up").font(.system(size: 24, weight: .bold)).foregroundStyle(ThemeColor.onSurface)
            Text("Detecting trackable tools…").font(.system(size: 13)).foregroundStyle(ThemeColor.onMuted)
            Spacer()
            HStack { Spacer(); ProgressView(); Spacer() }
            Spacer()
        }
    }

    private var sourcesPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("Sources")
            Text("Choose your sources").font(.system(size: 24, weight: .bold)).foregroundStyle(ThemeColor.onSurface)
            Text("Pick your IDEs, or skip.").font(.system(size: 13)).foregroundStyle(ThemeColor.onMuted)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.sources) { row in
                        HStack(spacing: 12) {
                            BrandIcon(appId: row.id, size: 28)
                            Text(row.label).font(.system(size: 13, weight: .bold)).foregroundStyle(ThemeColor.onSurface)
                            Spacer()
                            NativeSwitch(isOn: Binding(get: { row.enabled }, set: { viewModel.toggle(row.id, enabled: $0) }))
                        }
                        .frame(minHeight: 46)
                    }
                }
            }
            .scrollIndicators(.hidden)
            if let error = viewModel.errorMessage { Text(error).font(.system(size: 12)).foregroundStyle(ThemeColor.error) }
            HStack {
                Spacer()
                Button("Skip") { viewModel.finish(skip: true) }
                    .buttonStyle(.plain).foregroundStyle(ThemeColor.onSurface)
                    .padding(.horizontal, 14).frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(ThemeColor.outlineSoft, lineWidth: 1))
                    .disabled(viewModel.saving)
                Button("Continue") { viewModel.finish(skip: false) }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.primaryStrong))
                    .disabled(viewModel.saving)
            }
        }
    }

    private var donePane: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("All done")
            Text("You're all set").font(.system(size: 24, weight: .bold)).foregroundStyle(ThemeColor.onSurface)
            Text("Your tokens hatch today's creature story.").font(.system(size: 14)).italic().foregroundStyle(ThemeColor.gold)
            Text("Entering your dashboard…").font(.system(size: 13)).foregroundStyle(ThemeColor.onMuted)
            Spacer()
            HStack { Spacer(); Button("Enter now") { viewModel.enterDashboard() }
                .buttonStyle(.plain).foregroundStyle(.white)
                .padding(.horizontal, 14).frame(minHeight: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.primaryStrong)) }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            viewModel.enterDashboard()
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .bold)).tracking(0.14 * 10)
            .foregroundStyle(ThemeColor.primaryStrong).textCase(.uppercase)
    }
}
