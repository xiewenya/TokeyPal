import SwiftUI
import TokeyPalNative

struct ConfigView: View {
    @Bindable var viewModel: ConfigViewModel

    // 表单本地状态(从 VM 同步,提交时回写)
    @State private var idle = 60
    @State private var active = 10
    @State private var window = 5
    @State private var stage2 = 1
    @State private var stage3 = 50_000_000
    @State private var stage4 = 500_000_000

    var body: some View {
        VStack(spacing: 14) {
            ideMonitoringPanel
            blindBoxPanel
            otherSettingsPanel
            if viewModel.saved { Text("Saved").font(.system(size: 12)).foregroundStyle(ThemeColor.secondary) }
            if let error = viewModel.generalError { Text(error).font(.system(size: 12)).foregroundStyle(ThemeColor.error) }
        }
        .onAppear {
            viewModel.load()
            syncFromViewModel()
        }
        .overlay { directorySheet }
    }

    // MARK: - IDE 监控
    private var ideMonitoringPanel: some View {
        GamePanel(title: "IDE MONITORING") {
            VStack(spacing: 0) {
                ForEach(viewModel.sources) { row in
                    let (text, tone) = status(for: row)
                    UsageSourceRow(
                        model: row,
                        statusText: text,
                        statusTone: tone,
                        onToggle: { viewModel.toggleSource(row.id, enabled: $0) },
                        onConfigure: { viewModel.openDirectoryConfig(row.id) }
                    )
                    Divider().overlay(ThemeColor.outlineSoft)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func status(for row: UsageSourceRowModel) -> (String, StatusTone) {
        if viewModel.detectingApps.contains(row.id) { return ("Checking", .neutral) }
        guard row.enabled else { return ("Disabled", .neutral) }
        switch viewModel.detectionResults[row.id]?.status {
        case "detected": return ("Enabled", .detected)
        case "missing": return ("Needs Setup", .missing)
        default: return ("Waiting", .neutral)
        }
    }

    // MARK: - 盲盒设置
    private var blindBoxPanel: some View {
        GamePanel(title: "BLIND BOX SETTINGS") {
            VStack(spacing: 12) {
                HStack {
                    Text("Always on top").font(.system(size: 13, weight: .semibold)).foregroundStyle(ThemeColor.onSurface)
                    Spacer()
                    NativeSwitch(isOn: Binding(get: { viewModel.alwaysOnTop }, set: { viewModel.setAlwaysOnTop($0) }))
                }
                HStack {
                    Text("Size").font(.system(size: 13, weight: .semibold)).foregroundStyle(ThemeColor.onSurface)
                    Spacer()
                    SegmentedControl(
                        options: [(CompanionSizeMode.small, "S"), (.medium, "M"), (.large, "L")],
                        selection: Binding(get: { viewModel.size }, set: { viewModel.setSize($0) })
                    )
                }
                HStack(spacing: 14) {
                    numberField("Stage 2 threshold", value: $stage2) { commitThresholds() }
                    numberField("Stage 3 threshold", value: $stage3) { commitThresholds() }
                    numberField("Stage 4 threshold", value: $stage4) { commitThresholds() }
                }
            }
            .padding(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
        }
    }

    // MARK: - 其他设置
    private var otherSettingsPanel: some View {
        GamePanel(title: "OTHER SETTINGS") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    numberField("Idle polling (sec)", value: $idle) { viewModel.updateIdleSeconds(idle) }
                    numberField("Active polling (sec)", value: $active) { viewModel.updateActiveSeconds(active) }
                    numberField("Active window (min)", value: $window) { viewModel.updateActiveWindowMinutes(window) }
                }
                Text("More frequent polling increases CPU, memory, and ccusage subprocess activity.")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColor.onMuted)
            }
            .padding(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
        }
    }

    private func numberField(_ label: String, value: Binding<Int>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 14)).foregroundStyle(ThemeColor.onMuted)
            TextField("", value: value, format: .number)
                .textFieldStyle(.plain)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.surfaceLowest))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemeColor.outlineSoft, lineWidth: 1))
                .onSubmit(onCommit)
        }
        .frame(maxWidth: .infinity)
    }

    private func commitThresholds() {
        viewModel.updateThresholds(stage2: stage2, stage3: stage3, stage4: stage4)
        syncFromViewModel()
    }

    private func syncFromViewModel() {
        idle = viewModel.idleSeconds
        active = viewModel.activeSeconds
        window = viewModel.activeWindowMinutes
        stage2 = viewModel.stage2
        stage3 = viewModel.stage3
        stage4 = viewModel.stage4
    }

    @ViewBuilder
    private var directorySheet: some View {
        if let id = viewModel.configuringAppId {
            let label = viewModel.sources.first { $0.id == id }?.label ?? id
            DirectoryConfigSheet(
                appLabel: label,
                input: Binding(
                    get: { viewModel.directoryInputs[id] ?? "" },
                    set: { viewModel.changeDirectoryInput(id, $0) }
                ),
                placeholder: viewModel.defaultDirectoryInput(for: id),
                message: viewModel.detectionResults[id].flatMap { $0.status != "detected" ? $0.message : nil },
                error: viewModel.appErrors[id],
                onCheckAndSave: { viewModel.saveDirectories(id) },
                onClose: { viewModel.closeDirectoryConfig() }
            )
        }
    }
}
