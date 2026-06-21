import Foundation

/// 仅当未开启盲盒模式且该卡可选时,才允许手动选择。
public func canSelectCollectionCard(blindBoxModeEnabled: Bool, selectable: Bool) -> Bool {
    !blindBoxModeEnabled && selectable
}

public func stageLabel(_ stage: Int) -> String { "Stage \(stage)" }
