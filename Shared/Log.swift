import os

enum Log {
    static let subsystem = "io.github.joemrk.FinderOpenIn"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ext = Logger(subsystem: subsystem, category: "ext")
    static let runner = Logger(subsystem: subsystem, category: "runner")
    static let config = Logger(subsystem: subsystem, category: "config")
}
