import AppKit

/// 从 SwiftPM 资源包(Bundle.module)的指定子目录加载 PNG。
/// `.copy("UI/<dir>")` 保留目录结构,故需带 subdirectory。
enum BundleImage {
    static func load(_ name: String, subdirectory: String = "BrandIcons") -> NSImage? {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: subdirectory
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
