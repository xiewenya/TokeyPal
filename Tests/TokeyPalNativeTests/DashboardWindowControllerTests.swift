import Foundation
import Testing

private func windowControllerSource() throws -> String {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/TokeyPalNativeApp/DashboardWindowController.swift"),
        encoding: .utf8
    )
}

@Test func dashboardWindowIsFixedSizeAndOnlyUsesHeaderDragging() throws {
    let source = try windowControllerSource()
    #expect(!source.contains(".resizable"))
    #expect(source.contains("window.isMovableByWindowBackground = false"))
    #expect(source.contains("let dragView = DashboardDragView()"))
    #expect(source.contains("dragView.heightAnchor.constraint(equalToConstant: 76)"))
    #expect(source.contains("final class DashboardDragView: NSView"))
    #expect(source.contains("override func acceptsFirstMouse"))
    #expect(source.contains("window?.performDrag(with: event)"))
}

@Test func dashboardHostsNativeRootViewNotWebView() throws {
    let source = try windowControllerSource()
    #expect(source.contains("NSHostingView(rootView: RootView(store: store))"))
    #expect(!source.contains("WKWebView"))
    #expect(!source.contains("NativeBridge"))
}
