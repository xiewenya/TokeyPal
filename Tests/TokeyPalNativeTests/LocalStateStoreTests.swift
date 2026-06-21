import Foundation
import Testing
@testable import TokeyPalNative

// MARK: - LocalState / LocalStateStore 单元测试（精简后：仅 selectedCharacterId / blindBoxModeEnabled）

@Test func defaultLocalStateHasBlindBoxEnabledAndNoSelection() async throws {
    let state = LocalState.default
    #expect(state.selectedCharacterId == nil)
    #expect(state.blindBoxModeEnabled == true)
}

@Test func legacyTwoFieldJSONDecodesSuccessfully() async throws {
    // 旧版 blind-box-state.json 仅含 selectedCharacterId / blindBoxModeEnabled。
    let legacyJSON = """
    {
      "selectedCharacterId": "t-rex",
      "blindBoxModeEnabled": false
    }
    """
    let data = Data(legacyJSON.utf8)
    let state = try JSONDecoder().decode(LocalState.self, from: data)

    #expect(state.selectedCharacterId == "t-rex")
    #expect(state.blindBoxModeEnabled == false)
}

@Test func emptyObjectDecodesToDefaultsWithBlindBoxEnabled() async throws {
    let data = Data("{}".utf8)
    let state = try JSONDecoder().decode(LocalState.self, from: data)
    #expect(state.selectedCharacterId == nil)
    #expect(state.blindBoxModeEnabled == true)
}

@Test func decodingIgnoresLegacyExtraFields() async throws {
    // 旧版含已移除字段的文件仍须成功解码（宽容解码）。
    let json = """
    {
      "selectedCharacterId": "luna-cat",
      "blindBoxModeEnabled": true,
      "prefetchCache": ["a", "b"],
      "installRecords": {}
    }
    """
    let data = Data(json.utf8)
    let state = try JSONDecoder().decode(LocalState.self, from: data)
    #expect(state.selectedCharacterId == "luna-cat")
    #expect(state.blindBoxModeEnabled == true)
}

@Test func readingLegacyFilePreservesSelectionAndModeViaStore() async throws {
    let url = temporaryStateURL()
    let legacyJSON = """
    {
      "selectedCharacterId": "luna-cat",
      "blindBoxModeEnabled": true
    }
    """
    try Data(legacyJSON.utf8).write(to: url)

    let store = FileLocalStateStore(stateURL: url)
    let state = store.read()

    #expect(state.selectedCharacterId == "luna-cat")
    #expect(state.blindBoxModeEnabled == true)
}

@Test func roundTripViaStore() async throws {
    let url = temporaryStateURL()
    let store = FileLocalStateStore(stateURL: url)

    let original = LocalState(selectedCharacterId: "aurora-fox", blindBoxModeEnabled: false)
    try store.update { $0 = original }
    let reread = store.read()

    #expect(reread == original)
}

@Test func atomicUpdateMutatesInPlace() async throws {
    let url = temporaryStateURL()
    let store = FileLocalStateStore(stateURL: url)

    try store.update { $0.selectedCharacterId = "t-rex" }
    try store.update { $0.blindBoxModeEnabled = false }

    let state = store.read()
    #expect(state.selectedCharacterId == "t-rex")
    #expect(state.blindBoxModeEnabled == false)
}

@Test func missingFileReturnsDefault() async throws {
    let url = temporaryStateURL()
    let store = FileLocalStateStore(stateURL: url)
    #expect(store.read() == LocalState.default)
}

@Test func corruptFileReturnsDefault() async throws {
    let url = temporaryStateURL()
    try Data("{ this is not valid json".utf8).write(to: url)

    let store = FileLocalStateStore(stateURL: url)
    #expect(store.read() == LocalState.default)
}

private func temporaryStateURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("tokeypal-localstate-\(UUID().uuidString)")
        .appendingPathExtension("json")
}
