import SwiftUI

/// 左侧 Hero:4 张阶段卡扇形展开 + 发光 + 标题/引语。
struct OnboardingHero: View {
    let step: OnboardingViewModel.Step

    private let rotations: [Double] = [-15, -5, 5, 15]

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [ThemeColor.gold.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 90)
                    .offset(y: 70)
                    .blur(radius: 10)
                ForEach(Array(rotations.enumerated()), id: \.offset) { index, angle in
                    cardImage(index + 1)
                        .frame(width: 110)
                        .rotationEffect(.degrees(angle))
                        .offset(x: CGFloat(index - 2) * 26 + 13, y: abs(angle) > 10 ? 8 : 0)
                        .shadow(color: Color(.sRGB, red: 88.0/255.0, green: 56.0/255.0, blue: 25.0/255.0, opacity: 0.22), radius: 14, y: 14)
                }
            }
            .frame(width: 260, height: 280)

            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(ThemeColor.gold)
            if !quote.isEmpty {
                Text(quote).font(.system(size: 13)).italic().foregroundStyle(ThemeColor.onMuted)
                    .multilineTextAlignment(.center).frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: "#fffdf8"), Color(hex: "#fef6ec")], startPoint: .top, endPoint: .bottom)
        )
    }

    private func cardImage(_ i: Int) -> some View {
        Group {
            if let image = BundleImage.load("onboarding-stage\(i)", subdirectory: "OnboardingAssets") {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12).fill(ThemeColor.surfaceHigh)
            }
        }
    }

    private var title: String {
        step == .done ? "You're all set" : "Welcome to Tokey"
    }

    private var quote: String {
        switch step {
        case .detecting: return "Burn tokens to unlock my story."
        case .sources: return "Pick what I should watch."
        case .done: return ""
        }
    }
}
