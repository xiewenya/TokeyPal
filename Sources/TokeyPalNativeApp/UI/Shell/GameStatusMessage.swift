import SwiftUI

/// 还原 .game-status-message:圆角浅底提示条,可错误态。
struct GameStatusMessage: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(isError ? Color(hex: "#ffb096") : ThemeColor.onMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#fffaf1").opacity(0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isError
                                    ? Color(.sRGB, red: 1, green: 112.0 / 255.0, blue: 72.0 / 255.0, opacity: 0.45)
                                    : ThemeColor.outlineSoft,
                                lineWidth: 1
                            )
                    )
            )
    }
}
