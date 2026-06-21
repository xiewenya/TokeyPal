import SwiftUI

/// 还原 .settings-modal:自定义目录输入 + 检测 + 保存。
struct DirectoryConfigSheet: View {
    let appLabel: String
    @Binding var input: String
    let placeholder: String
    let message: String?
    let error: String?
    let onCheckAndSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.36).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CONFIGURE \(appLabel.uppercased()) DIRECTORIES")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(ThemeColor.onMuted)
                    Spacer()
                    Button("Close", action: onClose).buttonStyle(.plain).foregroundStyle(ThemeColor.onMuted)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Custom directories").font(.system(size: 14)).foregroundStyle(ThemeColor.onMuted)
                    TextField(placeholder, text: $input)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.surfaceLowest))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemeColor.outlineSoft, lineWidth: 1))
                }
                Button("CHECK AND SAVE", action: onCheckAndSave)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ThemeColor.surfaceHigh))
                if let message { Text(message).font(.system(size: 12)).foregroundStyle(ThemeColor.onMuted) }
                if let error { Text(error).font(.system(size: 12)).foregroundStyle(ThemeColor.error) }
            }
            .padding(16)
            .frame(width: 480)
            .background(RoundedRectangle(cornerRadius: 10).fill(ThemeColor.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ThemeColor.outlineSoft, lineWidth: 1))
        }
    }
}
