import SwiftUI

/// 从 file:// 绝对串加载本地图片(StageCard / deckBack 等)。失败渲染空占位。
struct RemoteFileImage: View {
    let urlString: String?
    var contentMode: ContentMode = .fit

    var body: some View {
        if let urlString, let url = URL(string: urlString), let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else {
            Color.clear
        }
    }
}
