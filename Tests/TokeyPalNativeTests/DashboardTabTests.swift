import Testing
@testable import TokeyPalNative

@Test func hasThreeDistinctTabs() {
    let cases = DashboardTab.allCases
    #expect(cases.count == 3)
    #expect(Set(cases.map(\.rawValue)).count == cases.count)
}

@Test func rawValuesRoundTripForEveryTab() {
    for tab in DashboardTab.allCases {
        #expect(DashboardTab(rawValue: tab.rawValue) == tab)
    }
}

@Test func headerTitleIsUppercasedNavTitle() {
    // 关系性断言:大标题是侧栏文案的大写形式,而非硬编码具体文案。
    for tab in DashboardTab.allCases {
        #expect(tab.headerTitle == tab.navTitle.uppercased())
        #expect(!tab.navTitle.isEmpty)
    }
}

@Test func everyTabHasDistinctNonEmptyIcon() {
    let icons = DashboardTab.allCases.map(\.navIconSystemName)
    #expect(icons.allSatisfy { !$0.isEmpty })
    #expect(Set(icons).count == icons.count)
}
