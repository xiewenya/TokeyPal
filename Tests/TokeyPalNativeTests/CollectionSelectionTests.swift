import Testing
@testable import TokeyPalNative

@Test func selectionRequiresModeOffAndSelectable() {
    #expect(canSelectCollectionCard(blindBoxModeEnabled: false, selectable: true))
    #expect(!canSelectCollectionCard(blindBoxModeEnabled: true, selectable: true))
    #expect(!canSelectCollectionCard(blindBoxModeEnabled: false, selectable: false))
}

@Test func stageLabelEmbedsStageNumber() {
    for s in 1...4 { #expect(stageLabel(s).contains(String(s))) }
    #expect(stageLabel(2) != stageLabel(3))
}
