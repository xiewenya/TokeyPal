import Testing
@testable import TokeyPalNative

@Test func compactTokensUsesKMSuffixesByThreshold() {
    #expect(formatCompactTokens(500) == "500")
    let k = formatCompactTokens(1_500)
    #expect(k.hasSuffix("K"))
    #expect(abs(Double(k.dropLast())! - 1.5) < 0.05)
    let m = formatCompactTokens(2_400_000)
    #expect(m.hasSuffix("M"))
    #expect(abs(Double(m.dropLast())! - 2.4) < 0.05)
    let b = formatCompactTokens(7_296_800_000)
    #expect(b.hasSuffix("B"))
    #expect(abs(Double(b.dropLast())! - 7.3) < 0.05)
    #expect(formatCompactTokens(-10) == "0")
}

@Test func compactCostPrefixedAndScaled() {
    let small = formatCompactCost(12.5)
    #expect(small.hasPrefix("US$"))
    #expect(abs(Double(small.dropFirst(3))! - 12.5) < 0.01)
    let big = formatCompactCost(2_000)
    #expect(big.hasPrefix("US$") && big.hasSuffix("K"))
    #expect(formatCompactCost(-5) == "US$0.00")
}

@Test func daysLabelDistinguishesSingularPluralZero() {
    #expect(formatDaysLabel(0) == "0")
    #expect(!formatDaysLabel(1).hasSuffix("s"))
    #expect(formatDaysLabel(1).contains("1"))
    #expect(formatDaysLabel(3).hasSuffix("s"))
    #expect(formatDaysLabel(3).contains("3"))
}

@Test func sharePercentClampsAndRatios() {
    #expect(usageSharePercent(value: 50, total: 200) == 25)
    #expect(usageSharePercent(value: 10, total: 0) == 0)
    #expect(usageSharePercent(value: 500, total: 100) == 100)
    #expect(usageSharePercent(value: 0, total: 100) == 0)
}
