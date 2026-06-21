import SwiftUI

/// 还原 .segmented-control:小圆角分段,选中段高亮。
struct SegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let active = option.value == selection
                Button {
                    if isEnabled { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(active ? ThemeColor.onSurface : ThemeColor.onMuted)
                        .frame(width: 36, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(active ? ThemeColor.surfaceHigh : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: ThemeMetric.buttonCornerRadius)
                .fill(ThemeColor.surfaceLow)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeMetric.buttonCornerRadius)
                        .stroke(ThemeColor.outlineSoft, lineWidth: 1)
                )
        )
        .opacity(isEnabled ? 1 : 0.5)
    }
}
