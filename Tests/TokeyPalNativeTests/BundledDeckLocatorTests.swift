import Foundation
import Testing
@testable import TokeyPalNative

// MARK: - 测试支撑

private let resourcesRoot = URL(fileURLWithPath: "/tokey/Resources", isDirectory: true)
private let appSupportRoot = URL(fileURLWithPath: "/tokey/AppSupport/TokeyPal", isDirectory: true)

/// 用一组"存在的目录"路径集合构造可注入的存在性探测闭包（无真实文件系统）。
private func existsAmong(_ paths: Set<String>) -> @Sendable (URL) -> Bool {
    { url in paths.contains(url.path) }
}

private func makeLocator(existing: Set<String> = []) -> BundledDeckLocator {
    BundledDeckLocator(
        resourcesRoot: resourcesRoot,
        appSupportRoot: appSupportRoot,
        directoryExists: existsAmong(existing)
    )
}

// MARK: - 基路径解析（Req 6.1 / 6.3）

@Test("bundled 卡组解析到 Resources/data/{id}")
func bundledBasePathResolvesToResourcesData() {
    let locator = makeLocator()

    let path = locator.basePath(for: .bundled(deckId: "t-rex"))

    #expect(path.path == "/tokey/Resources/data/t-rex")
    #expect(locator.bundledBasePath(deckId: "wolf").path == "/tokey/Resources/data/wolf")
}

@Test("remote 卡组解析到 Local_Asset_Store decks/{deckId}/{version}")
func remoteBasePathResolvesToVersionedLocalAssetStore() {
    let locator = makeLocator()

    let path = locator.basePath(for: .remote(deckId: "aurora-fox", version: "2026.01.06"))

    #expect(path.path == "/tokey/AppSupport/TokeyPal/decks/aurora-fox/2026.01.06")
    #expect(locator.remoteBasePath(deckId: "luna-cat", version: "1.0.0").path
        == "/tokey/AppSupport/TokeyPal/decks/luna-cat/1.0.0")
}

@Test("按 isBundled 标志解析：bundled 忽略 version 用 Resources/data，remote 用版本化路径")
func basePathByIsBundledFlag() {
    let locator = makeLocator()

    let bundled = locator.basePath(deckId: "fire-dragon", version: "ignored", isBundled: true)
    #expect(bundled.path == "/tokey/Resources/data/fire-dragon")

    let remote = locator.basePath(deckId: "pixel-dog", version: "2026.02.01", isBundled: false)
    #expect(remote.path == "/tokey/AppSupport/TokeyPal/decks/pixel-dog/2026.02.01")
}

@Test("bundled 与 remote 基路径在不同的根下（互不重叠）")
func bundledAndRemoteRootsAreDistinct() {
    let locator = makeLocator()

    let bundled = locator.basePath(deckId: "t-rex", version: "v", isBundled: true)
    let remote = locator.basePath(deckId: "t-rex", version: "v", isBundled: false)

    #expect(bundled != remote)
    #expect(bundled.path.hasPrefix("/tokey/Resources/data"))
    #expect(remote.path.hasPrefix("/tokey/AppSupport/TokeyPal/decks"))
}

// MARK: - 本地可用性（Req 6.1 / 6.3）

@Test("免费内置卡组为已知 bundled 集合")
func freeBundledDecksAreKnown() {
    let locator = makeLocator()

    #expect(BundledDeckLocator.bundledDeckIds == ["t-rex"])
    #expect(BundledDeckLocator.bundledDeckIds.count == 1)
    #expect(locator.isKnownBundledDeck("t-rex"))
    #expect(!locator.isKnownBundledDeck("fire-dragon"))
    #expect(!locator.isKnownBundledDeck("aurora-fox"))
}

@Test("随包就位的内置卡组本地可用、无需下载")
func bundledDecksAreAvailableOfflineWhenPresent() {
    // 内置卡组目录随包位于 Resources/data/{id}。
    let existing: Set<String> = [
        "/tokey/Resources/data/t-rex"
    ]
    let locator = makeLocator(existing: existing)

    for deckId in BundledDeckLocator.bundledDeckIds {
        #expect(locator.isLocallyAvailableWithoutDownload(deckId: deckId))
    }
    #expect(locator.availableBundledDeckIds() == ["t-rex"])
}

@Test("Resources/data 缺失目录时该卡组不被判为本地可用")
func missingBundledDirectoryIsNotLocallyAvailable() {
    // 仅 t-rex 随包就位。
    let locator = makeLocator(existing: ["/tokey/Resources/data/t-rex"])

    #expect(locator.isLocallyAvailableWithoutDownload(deckId: "t-rex"))
    #expect(!locator.isLocallyAvailableWithoutDownload(deckId: "wolf"))
    #expect(!locator.isLocallyAvailableWithoutDownload(deckId: "fire-dragon"))
    #expect(locator.availableBundledDeckIds() == ["t-rex"])
}

@Test("远程卡组不被误判为内置本地可用")
func remoteDeckIsNotBundledAvailable() {
    // 即便 Local_Asset_Store 下存在该远程卡组的安装目录，它也不应被当作 bundled 本地可用。
    let existing: Set<String> = ["/tokey/AppSupport/TokeyPal/decks/aurora-fox/2026.01.06"]
    let locator = makeLocator(existing: existing)

    #expect(!locator.isKnownBundledDeck("aurora-fox"))
    #expect(!locator.isLocallyAvailableWithoutDownload(deckId: "aurora-fox"))
}

// MARK: - 与真实 Resources/data 集成（确认免费卡组随包就位）

@Test("真实 Resources/data 中免费内置卡组随包就位且本地可用")
func realResourcesContainBundledDecks() throws {
    // 定位仓库内的 Resources 目录（相对本测试源文件）。
    let testFile = URL(fileURLWithPath: #filePath)
    let projectRoot = testFile
        .deletingLastPathComponent() // TokeyPalNativeTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // tokey-mac
    let realResources = projectRoot.appendingPathComponent("Resources", isDirectory: true)

    // 仅当能定位到真实 Resources/data 时执行（默认 FileManager 探测）。
    let locator = BundledDeckLocator(resourcesRoot: realResources, appSupportRoot: appSupportRoot)
    let dataExists = BundledDeckLocator.defaultDirectoryExists(locator.dataRoot)
    try #require(dataExists)

    for deckId in BundledDeckLocator.bundledDeckIds {
        #expect(
            locator.isLocallyAvailableWithoutDownload(deckId: deckId),
            "内置卡组 \(deckId) 应随包位于 Resources/data/\(deckId)"
        )
    }
}
