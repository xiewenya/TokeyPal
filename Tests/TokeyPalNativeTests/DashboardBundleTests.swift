import Foundation
import Testing

private func projectRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Test func nativeAppDoesNotReferenceElectronProjectPaths() throws {
    let root = projectRoot()
    let fileManager = FileManager.default
    let checkedRoots = [
        "Sources",
        "Tests",
        "scripts",
        "README.md",
        "Package.swift",
    ]
    let forbidden = [
        "../tokeypal",
        "/Users/bresai/code/tokeypal/",
        "/Volumes/mac/code/tokeypal/",
        "~/code/tokeypal/",
        "TOKEYPAL_RESOURCE_ROOT",
    ]
    let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "pdf", "icns", "car", "ico", "tiff",
    ]

    for relativeRoot in checkedRoots {
        let url = root.appendingPathComponent(relativeRoot)
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let files: [URL]
        if isDirectory {
            files = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])?
                .compactMap { $0 as? URL }
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true } ?? []
        } else {
            files = [url]
        }

        for file in files {
            if file.lastPathComponent == "DashboardBundleTests.swift" { continue }
            if file.lastPathComponent.hasPrefix(".") { continue }
            if binaryExtensions.contains(file.pathExtension.lowercased()) { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            for value in forbidden {
                #expect(!text.contains(value), "\(file.path) contains \(value)")
            }
        }
    }
}
