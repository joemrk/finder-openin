import Cocoa

/// Shows a failed command launch as a modal window centered on screen.
enum FailureAlert {
    static func show(_ notice: FailureNotice) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = notice.title
            alert.informativeText = notice.body
            alert.addButton(withTitle: "OK")
            // The app has no Dock icon: without this the window would stay behind others.
            alert.window.level = .floating
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
