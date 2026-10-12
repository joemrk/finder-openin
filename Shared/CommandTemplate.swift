import Foundation

enum CommandTemplate {
    static let placeholder = "{path}"

    /// Replaces `{path}` inside every token. The number of tokens does not change.
    static func expand(_ cmd: [String], path: String) -> [String] {
        cmd.map { $0.replacingOccurrences(of: placeholder, with: path) }
    }
}
