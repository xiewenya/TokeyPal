import Foundation

public func companionDisplayUrl(from state: CompanionState) -> URL? {
    [state.animationUrl, state.characterUrl, state.coverUrl]
        .compactMap { $0 }
        .compactMap(URL.init(string:))
        .first
}
