import Foundation

enum DefaultConfig {
    static let json = """
    [
      { "title": "Antigravity", "cmd": ["antigravity-ide", "{path}"] },
      { "title": "VS Code", "cmd": ["code", "{path}"] },
      { "title": "Zed", "cmd": ["zed", "{path}"] }
    ]

    """

    static func installIfMissing(at url: URL?) {
        guard let url else {
            Log.config.error("no app group container; default config not installed")
            return
        }
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try Data(json.utf8).write(to: url, options: .atomic)
            Log.config.info("installed default config at \(url.path, privacy: .public)")
        } catch {
            Log.config.error("cannot install default config: \(error.localizedDescription, privacy: .public)")
        }
    }
}
