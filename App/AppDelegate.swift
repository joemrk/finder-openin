import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenu?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("launched")
        DefaultConfig.installIfMissing(at: ConfigLocation.configURL)
        statusMenu = StatusMenu()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let request = RunRequest(url: url) else {
                Log.app.error("unrecognized URL: \(url.absoluteString, privacy: .public)")
                continue
            }
            Log.app.info("request \(request.id, privacy: .public) for \(request.path, privacy: .public)")
            CommandRunner.run(request, configURL: ConfigLocation.configURL) { notice in
                FailureAlert.show(notice)
            }
        }
    }
}
