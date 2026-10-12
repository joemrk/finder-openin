import Cocoa
import FinderSync

final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    override init() {
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.up.forward.app",
                                           accessibilityDescription: "Finder Open In")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(makeItem("Open Config", #selector(openConfig)))
        menu.addItem(makeItem("Extension Settings…", #selector(openExtensionSettings)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit", #selector(quit)))
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        stateItem.title = Self.stateTitle()
    }

    private static func stateTitle() -> String {
        guard let url = ConfigLocation.configURL else { return "Config error — see log" }
        switch ConfigLoader.load(from: url) {
        case .success(let commands):
            return commands.count == 1 ? "1 command" : "\(commands.count) commands"
        case .failure(let error):
            Log.app.error("config error: \(String(describing: error), privacy: .public)")
            return "Config error — see log"
        }
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openConfig() {
        DefaultConfig.installIfMissing(at: ConfigLocation.configURL)
        guard let url = ConfigLocation.configURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
