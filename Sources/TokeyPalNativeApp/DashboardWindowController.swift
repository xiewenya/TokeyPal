import AppKit
import Foundation
import SwiftUI
import TokeyPalNative

@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    private let store: AppStore
    private var window: NSWindow?
    private var hostingView: NSHostingView<RootView>?
    private var lifecycle = DashboardLifecycle()
    private var idleDestroyTimer: Timer?
    private let idleDestroyInterval: TimeInterval

    init(store: AppStore, idleDestroyInterval: TimeInterval = 300) {
        self.store = store
        self.idleDestroyInterval = idleDestroyInterval
        super.init()
    }

    func show() {
        show(tab: nil)
    }

    /// 打开窗口并切到指定 Tab(tab 为固定内部集合的 id,见 DashboardTab)。
    func show(tab: String?) {
        if let tab {
            store.select(rawTab: tab)
        }
        apply(lifecycle.open())
        apply(lifecycle.ready())
    }

    func close() {
        apply(lifecycle.close())
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        close()
        return false
    }

    private func createHiddenWindowIfNeeded() {
        guard window == nil, hostingView == nil else {
            return
        }

        let dashboardSize = NSSize(width: 1120, height: 760)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: dashboardSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TokeyPal"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.contentMinSize = dashboardSize
        window.contentMaxSize = dashboardSize
        window.appearance = NSAppearance(named: .aqua)
        window.center()

        let contentView = NSView(frame: NSRect(origin: .zero, size: dashboardSize))
        let host = NSHostingView(rootView: RootView(store: store))
        host.translatesAutoresizingMaskIntoConstraints = false
        let dragView = DashboardDragView()
        dragView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(host)
        contentView.addSubview(dragView)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            host.topAnchor.constraint(equalTo: contentView.topAnchor),
            host.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dragView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dragView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dragView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dragView.heightAnchor.constraint(equalToConstant: 76)
        ])
        window.contentView = contentView

        self.window = window
        self.hostingView = host
        window.delegate = self
    }

    private func showWindow() {
        guard let window else {
            return
        }
        window.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func hideWindow() {
        window?.orderOut(nil)
    }

    private func scheduleIdleDestroy() {
        idleDestroyTimer?.invalidate()
        idleDestroyTimer = Timer.scheduledTimer(withTimeInterval: idleDestroyInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.apply(self?.lifecycle.idleTimeout() ?? [])
            }
        }
    }

    private func cancelIdleDestroy() {
        idleDestroyTimer?.invalidate()
        idleDestroyTimer = nil
    }

    private func destroyDashboard() {
        cancelIdleDestroy()
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }

    private func apply(_ effects: [DashboardLifecycleEffect]) {
        for effect in effects {
            switch effect {
            case .createHidden:
                createHiddenWindowIfNeeded()
            case .load:
                break // SwiftUI 即时渲染,无需异步加载
            case .show:
                showWindow()
            case .hide:
                hideWindow()
            case .scheduleDestroy:
                scheduleIdleDestroy()
            case .cancelDestroy:
                cancelIdleDestroy()
            case .destroy:
                destroyDashboard()
            }
        }
    }
}

/// 顶部 76pt 拖拽区:固定尺寸窗口仅靠此区域移动。
final class DashboardDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0 else {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }
}
