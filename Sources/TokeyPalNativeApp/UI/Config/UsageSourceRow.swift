import SwiftUI
import TokeyPalNative

enum StatusTone {
    case detected, missing, neutral
}

/// 还原 .status-marker:状态徽标。
struct StatusMarker: View {
    let text: String
    let tone: StatusTone

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .frame(minWidth: 86, minHeight: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(background))
    }

    private var foreground: Color {
        switch tone {
        case .detected: return ThemeColor.secondary
        case .missing: return ThemeColor.error
        case .neutral: return ThemeColor.onMuted
        }
    }

    private var background: Color {
        switch tone {
        case .detected: return ThemeColor.secondary.opacity(0.18)
        case .missing: return ThemeColor.error.opacity(0.16)
        case .neutral: return ThemeColor.surfaceHigh
        }
    }
}

/// 还原 .usage-app-row:图标 + 名称 + 状态徽标 + 开关 + Configure。
struct UsageSourceRow: View {
    let model: UsageSourceRowModel
    let statusText: String
    let statusTone: StatusTone
    let onToggle: (Bool) -> Void
    let onConfigure: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BrandIcon(appId: model.id, size: 28)
            Text(model.label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ThemeColor.onSurface)
            Spacer()
            StatusMarker(text: statusText, tone: statusTone)
            NativeSwitch(isOn: Binding(get: { model.enabled }, set: { onToggle($0) }))
            Button(action: onConfigure) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemeColor.onSurface)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: ThemeMetric.buttonCornerRadius)
                            .stroke(ThemeColor.outlineSoft, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Configure")
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 50)
    }
}
