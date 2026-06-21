import SwiftUI
import TokeyPalNative

/// 单应用用量表:App / Total / Today / Cost / Days / Today%。
struct UsageTable: View {
    let stats: UsageStats

    private var apps: [UsageAppStats] { stats.apps.filter { $0.enabled } }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(apps, id: \.appId) { app in
                row(app)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var headerRow: some View {
        gridRow(
            app: AnyView(Text("App")),
            total: AnyView(Text("Total Tokens")),
            today: AnyView(Text("Today")),
            cost: AnyView(Text("Cost")),
            days: AnyView(Text("Days")),
            share: AnyView(Text("Today Tokens %")),
            isHeader: true
        )
    }

    private func row(_ app: UsageAppStats) -> some View {
        let share = usageSharePercent(value: app.todayTokens, total: stats.totals.todayTokens)
        return gridRow(
            app: AnyView(
                HStack(spacing: 10) {
                    BrandIcon(appId: app.appId, size: 22)
                    Text(app.label).lineLimit(1)
                }
            ),
            total: AnyView(Text(formatCompactTokens(app.totalTokens)).monospacedDigit()),
            today: AnyView(Text(formatCompactTokens(app.todayTokens)).monospacedDigit()),
            cost: AnyView(Text(formatCompactCost(app.totalCost)).monospacedDigit()),
            days: AnyView(Text(formatDaysLabel(app.daysWithUsage))),
            share: AnyView(shareCell(share)),
            isHeader: false
        )
    }

    private func shareCell(_ share: Int) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ThemeColor.surfaceHigh)
                    Capsule()
                        .fill(LinearGradient(colors: [ThemeColor.primaryStrong, ThemeColor.secondary], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * CGFloat(share) / 100))
                }
            }
            .frame(height: 8)
            Text("\(share)%").font(.system(size: 11, weight: .bold)).foregroundStyle(ThemeColor.onMuted).frame(width: 28, alignment: .trailing)
        }
    }

    private func gridRow(
        app: AnyView, total: AnyView, today: AnyView, cost: AnyView,
        days: AnyView, share: AnyView, isHeader: Bool
    ) -> some View {
        HStack(spacing: 12) {
            app.frame(maxWidth: .infinity, alignment: .leading)
            total.frame(maxWidth: .infinity, alignment: .leading)
            today.frame(maxWidth: .infinity, alignment: .leading)
            cost.frame(maxWidth: .infinity, alignment: .leading)
            days.frame(maxWidth: .infinity, alignment: .leading)
            share.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: isHeader ? 11 : 13, weight: isHeader ? .black : .bold))
        .tracking(isHeader ? 0.11 * 11 : 0)
        .textCase(isHeader ? .uppercase : nil)
        .foregroundStyle(isHeader ? ThemeColor.primaryStrong : ThemeColor.onSurface)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(minHeight: isHeader ? 42 : 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.sRGB, red: 89.0 / 255.0, green: 59.0 / 255.0, blue: 33.0 / 255.0, opacity: 0.1))
                .frame(height: 1)
        }
    }
}
