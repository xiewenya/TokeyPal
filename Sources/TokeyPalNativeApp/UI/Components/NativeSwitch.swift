import SwiftUI

/// 还原 .native-switch:36×20 轨道,开启红色,16×16 白色滑块。
struct NativeSwitch: View {
    @Binding var isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 999)
                .fill(isOn ? Color(hex: "#ef5a50") : ThemeColor.surfaceHigh)
                .frame(width: 36, height: 20)
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .padding(.horizontal, 2)
                .shadow(
                    color: Color(.sRGB, red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0, opacity: 0.24),
                    radius: 1,
                    y: 1
                )
        }
        .frame(width: 36, height: 20)
        .animation(.easeInOut(duration: 0.12), value: isOn)
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { isOn.toggle() } }
        .allowsHitTesting(isEnabled)
    }
}
