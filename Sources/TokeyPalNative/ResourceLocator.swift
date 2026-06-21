import Foundation

public struct ResourceLocator: Sendable {
    public let resourcesRoot: URL

    public init(projectRoot: URL) {
        self.resourcesRoot = projectRoot.appendingPathComponent("Resources", isDirectory: true)
    }

    public init(resourcesRoot: URL) {
        self.resourcesRoot = resourcesRoot
    }

    public init() {
        self.resourcesRoot = Self.resolveDefaultResourcesRoot()
    }

    public var assetsRoot: URL {
        resourcesRoot.appendingPathComponent("assets", isDirectory: true)
    }

    public var dataRoot: URL {
        resourcesRoot.appendingPathComponent("data", isDirectory: true)
    }

    public var ccusageURL: URL {
        resourcesRoot.appendingPathComponent("bin/ccusage")
    }

    public func url(relativePath: String) -> URL {
        resourcesRoot.appendingPathComponent(relativePath)
    }

    public static func applicationSupportRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("TokeyPal", isDirectory: true)
    }

    private static func resolveDefaultResourcesRoot() -> URL {
        let fileManager = FileManager.default

        if let resourceURL = Bundle.main.resourceURL,
           fileManager.fileExists(atPath: resourceURL.appendingPathComponent("data").path) {
            return resourceURL
        }

        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        if fileManager.fileExists(atPath: current.appendingPathComponent("data").path) {
            return current
        }

        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return projectRoot.appendingPathComponent("Resources", isDirectory: true)
    }
}
