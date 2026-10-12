import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    /// Commands the last menu was built from; an item's `tag` is its index in this array.
    private var snapshot: [Command] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        Log.ext.info("extension loaded")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return menu
        }
        snapshot = loadCommands()
        for (index, command) in snapshot.enumerated() {
            let item = NSMenuItem(title: "Open in \(command.title)",
                                  action: #selector(runCommand(_:)),
                                  keyEquivalent: "")
            item.tag = index
            menu.addItem(item)
        }
        return menu
    }

    @objc func runCommand(_ sender: NSMenuItem) {
        guard snapshot.indices.contains(sender.tag) else {
            Log.ext.error("menu item tag \(sender.tag) is out of range")
            return
        }
        let command = snapshot[sender.tag]
        let controller = FIFinderSyncController.default()
        guard let path = RunRequest.targetPath(selected: controller.selectedItemURLs() ?? [],
                                               targeted: controller.targetedURL()) else {
            Log.ext.error("no target for \(command.title, privacy: .public)")
            return
        }
        let url = RunRequest(id: command.title, path: path).url
        let opened = NSWorkspace.shared.open(url)
        Log.ext.info("sent \(command.title, privacy: .public) for \(path, privacy: .public): \(opened)")
    }

    private func loadCommands() -> [Command] {
        guard let url = ConfigLocation.configURL else {
            Log.ext.error("no app group container")
            return []
        }
        switch ConfigLoader.load(from: url) {
        case .success(let commands):
            return commands
        case .failure(let error):
            Log.ext.error("config error: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
