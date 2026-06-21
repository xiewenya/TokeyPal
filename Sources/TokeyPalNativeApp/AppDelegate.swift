import AppKit
import Foundation
import SDWebImage
import SDWebImageWebPCoder
import SwiftUI
import TokeyPalNative

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dashboardController: DashboardWindowController?
    private var companionPanel: CompanionPanelController?
    private var resources: ResourceLocator?
    private var appStore: AppStore?
    private var settingsStore: SettingsStore?
    private var usageService: UsageService?
    private var usagePolling = UsagePollingController(settings: .default)
    private var pollingTimer: Timer?
    private var pollingInFlight = false
    private var companionRuntime: CompanionRuntime?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)

        do {
            let resources = ResourceLocator()
            let supportRoot = ResourceLocator.applicationSupportRoot()
            let settingsURL = supportRoot.appendingPathComponent("settings.json")
            let settingsStore = SettingsStore(settingsURL: settingsURL)
            let runner = CcusageRunner(executableURL: resources.ccusageURL)
            let cacheStore = UsageCacheStore(cacheURL: supportRoot.appendingPathComponent("ccusage-raw-cache.json"))
            let usageService = UsageService(runner: runner, cacheStore: cacheStore)
            let companionRuntime = try CompanionRuntime(resources: resources)
            let companionPanel = try CompanionPanelController(
                settingsStore: settingsStore,
                usageService: usageService,
                runtime: companionRuntime
            )

            let store = AppStore(
                settingsStore: settingsStore,
                usageService: usageService,
                companionRuntime: companionRuntime
            )
            store.settingsDidChange = { [weak companionPanel] settings in
                companionPanel?.apply(settings: settings)
                companionPanel?.refreshImage()
            }

            self.resources = resources
            self.settingsStore = settingsStore
            self.usageService = usageService
            self.companionPanel = companionPanel
            self.appStore = store
            self.companionRuntime = companionRuntime
            companionPanel.contextMenuProvider = { [weak self] in
                self?.buildMenu() ?? NSMenu(title: "TokeyPal")
            }
            setupStatusItem()
            refreshUsageAndScheduleNext()
            companionPanel.show()

            if shouldAutoOpenOnboarding((try? settingsStore.read()) ?? .default) {
                openDashboard()
            }
        } catch {
            showStartupError(error)
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = loadTrayTemplateImage()
            button.imagePosition = .imageLeading
            // 让图标与文字共享同一竖直中心:图标按文字大写字母高度居中,文字用菜单栏字号。
            button.imageHugsTitle = true
            applyTrayTitle("TokeyPal", to: button)
        }
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    /// 用带基线微调的富文本设置托盘标题,使其与模板图标竖直居中对齐。
    private func applyTrayTitle(_ text: String, to button: NSStatusBarButton? = nil) {
        guard let button = button ?? statusItem?.button else { return }
        guard !text.isEmpty else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium),
            .baselineOffset: 1.0,
            .foregroundColor: NSColor.labelColor
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
    }

    private func loadTrayTemplateImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "trayTemplate", withExtension: "png", subdirectory: "app-icon"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "TokeyPal")
        populateMenu(menu)
        return menu
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let companion = companionPanel?.companionSettings ?? .default

        menu.addItem(actionItem(title: "Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(actionItem(title: "Collections", action: #selector(openCollections)))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(actionItem(title: "Config", action: #selector(openConfig)))
        menu.addItem(buildCompanionSizeItem(current: companion.size))
        menu.addItem(buildAlwaysOnTopItem(enabled: companion.alwaysOnTop))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildAboutItem())
        menu.addItem(actionItem(title: "Quit TokeyPal", action: #selector(quit), keyEquivalent: "q"))
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func buildCompanionSizeItem(current: CompanionSizeMode) -> NSMenuItem {
        let item = NSMenuItem(title: "Companion Size", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Companion Size")
        let options: [(String, CompanionSizeMode)] = [
            ("Small", .small),
            ("Medium", .medium),
            ("Large", .large)
        ]
        for (title, mode) in options {
            let option = actionItem(title: title, action: #selector(changeCompanionSize(_:)))
            option.representedObject = mode.rawValue
            option.state = mode == current ? .on : .off
            submenu.addItem(option)
        }
        item.submenu = submenu
        return item
    }

    private func buildAlwaysOnTopItem(enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: "Always on Top", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Always on Top")
        let enableItem = actionItem(title: "Enable", action: #selector(enableAlwaysOnTop))
        enableItem.state = enabled ? .on : .off
        let disableItem = actionItem(title: "Disable", action: #selector(disableAlwaysOnTop))
        disableItem.state = enabled ? .off : .on
        submenu.addItem(enableItem)
        submenu.addItem(disableItem)
        item.submenu = submenu
        return item
    }

    private func buildAboutItem() -> NSMenuItem {
        let item = NSMenuItem(title: "About", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "About")
        let info = Bundle.main.infoDictionary
        let displayName = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? "TokeyPal"
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildVersion = info?["CFBundleVersion"] as? String ?? "unknown"
        let bundleId = info?["CFBundleIdentifier"] as? String ?? "local.tokeypal.mac"

        for line in [
            displayName,
            "Your AI usage companion",
            "Version \(shortVersion) (Build \(buildVersion))",
            bundleId
        ] {
            let infoItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            infoItem.isEnabled = false
            submenu.addItem(infoItem)
        }
        item.submenu = submenu
        return item
    }

    private func refreshUsageAndScheduleNext() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        guard !pollingInFlight, let settingsStore, let usageService else {
            return
        }

        pollingInFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self, settingsStore, usageService] in
            let result = Result { () throws -> (TokeyPalSettings, UsageStats) in
                let settings = try settingsStore.read()
                return (settings, try usageService.currentStats(settings: settings))
            }

            DispatchQueue.main.async {
                self?.pollingInFlight = false
                self?.handleUsageRefresh(result)
            }
        }
    }

    private func handleUsageRefresh(_ result: Result<(TokeyPalSettings, UsageStats), Error>) {
        let intervalMs: Int
        switch result {
        case .success(let (_, stats)):
            let settings = (try? settingsStore?.read()) ?? .default
            usagePolling.updateSettings(settings.polling)
            let snapshot = UsageService.snapshot(from: stats, previousTotalTokens: usagePolling.state.currentTokens)
            _ = usagePolling.record(snapshot: snapshot)
            statusItem?.button.map { applyTrayTitle(formatTrayUsageTitle(stats.totals.todayTokens), to: $0) }
            companionPanel?.apply(settings: settings)
            companionPanel?.refreshImage(todayTokens: stats.totals.todayTokens)
            intervalMs = usagePolling.nextIntervalMs
        case .failure:
            var snapshot = UsageSnapshot(
                localDate: UsageService.localDateString(),
                progressTokens: usagePolling.state.currentTokens,
                exactTokens: usagePolling.state.currentTokens,
                estimatedTokens: 0,
                sources: [],
                dataStatus: "source_error",
                accuracy: "exact",
                recentTokenDelta: 0
            )
            snapshot.recentTokenDelta = 0
            _ = usagePolling.record(snapshot: snapshot)
            intervalMs = usagePolling.nextIntervalMs
        }

        schedulePolling(afterMs: intervalMs)
    }

    private func schedulePolling(afterMs intervalMs: Int) {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMs) / 1000, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUsageAndScheduleNext()
            }
        }
    }

    @objc private func openDashboard() {
        presentDashboard(tab: nil)
    }

    @objc private func openCollections() {
        presentDashboard(tab: "blindBox")
    }

    @objc private func openConfig() {
        presentDashboard(tab: "config")
    }

    private func presentDashboard(tab: String?) {
        guard let appStore else {
            return
        }
        let controller = dashboardController ?? DashboardWindowController(store: appStore)
        dashboardController = controller
        controller.show(tab: tab)
    }

    @objc private func changeCompanionSize(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = CompanionSizeMode(rawValue: rawValue) else {
            return
        }
        companionPanel?.setSize(mode)
    }

    @objc private func enableAlwaysOnTop() {
        companionPanel?.setAlwaysOnTop(true)
    }

    @objc private func disableAlwaysOnTop() {
        companionPanel?.setAlwaysOnTop(false)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "TokeyPal could not start"
        alert.informativeText = String(describing: error)
        alert.alertStyle = .critical
        alert.runModal()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Rebuild the status-bar menu each time it opens so the size and
        // always-on-top selections reflect the current companion settings.
        populateMenu(menu)
    }
}
