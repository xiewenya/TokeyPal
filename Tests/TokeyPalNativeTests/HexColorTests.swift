import Testing
@testable import TokeyPalNative

@Test func parsesSixDigitHexWithHash() {
    let c = rgbaComponents(hex: "#D97757")
    #expect(c != nil)
    #expect(abs(c!.red - 217.0 / 255.0) < 0.001)
    #expect(abs(c!.green - 119.0 / 255.0) < 0.001)
    #expect(abs(c!.blue - 87.0 / 255.0) < 0.001)
    #expect(c!.alpha == 1.0)
}

@Test func parsesShortHexWithoutHash() {
    let c = rgbaComponents(hex: "fff")
    #expect(c != nil)
    #expect(c!.red == 1.0 && c!.green == 1.0 && c!.blue == 1.0 && c!.alpha == 1.0)
}

@Test func parsesEightDigitHexAlpha() {
    let c = rgbaComponents(hex: "#000000FF")
    #expect(c != nil)
    #expect(c!.alpha == 1.0 && c!.red == 0.0)
}

@Test func parsesHalfAlphaWithinTolerance() {
    let c = rgbaComponents(hex: "#11223380")
    #expect(c != nil)
    #expect(abs(c!.alpha - 128.0 / 255.0) < 0.001)
}

@Test func rejectsInvalidHex() {
    #expect(rgbaComponents(hex: "#xyz") == nil)
    #expect(rgbaComponents(hex: "12") == nil)
}
