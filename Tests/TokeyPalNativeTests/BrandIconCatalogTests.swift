import Testing
@testable import TokeyPalNative

@Test func visibleAppAssetNamesAreInputDerived() {
    // 关系性断言:资源名由 appId 派生(brand-<id>),而非逐个硬编码字符串。
    for appId in BrandIconCatalog.visibleAppIds {
        #expect(BrandIconCatalog.spec(for: appId).assetName == "brand-\(appId)")
    }
}

@Test func visibleAppsProduceDistinctAssets() {
    let names = BrandIconCatalog.visibleAppIds.map { BrandIconCatalog.spec(for: $0).assetName }
    #expect(Set(names).count == names.count)
}

@Test func monoSpecsCarryDistinctAvatarColorsColorSpecsDoNot() {
    // 不预设哪个是单色,只校验"单色↔头像双色非空且不同;彩色↔头像色为空"的不变式。
    for appId in BrandIconCatalog.visibleAppIds {
        let spec = BrandIconCatalog.spec(for: appId)
        if spec.isMono {
            #expect(spec.avatarBackgroundHex != nil)
            #expect(spec.avatarForegroundHex != nil)
            #expect(spec.avatarBackgroundHex != spec.avatarForegroundHex)
        } else {
            #expect(spec.avatarBackgroundHex == nil)
            #expect(spec.avatarForegroundHex == nil)
        }
    }
}

@Test func unknownAppsShareTheFallbackAsset() {
    let a = BrandIconCatalog.spec(for: "droid")
    let b = BrandIconCatalog.spec(for: "totally-unknown")
    #expect(a.assetName == BrandIconCatalog.fallbackAssetName)
    #expect(a.assetName == b.assetName)
    #expect(a.isMono == false)
}

@Test func everyAssetNameUsesBrandPrefix() {
    var names = BrandIconCatalog.visibleAppIds.map { BrandIconCatalog.spec(for: $0).assetName }
    names.append(BrandIconCatalog.fallbackAssetName)
    #expect(names.allSatisfy { $0.hasPrefix("brand-") })
}
