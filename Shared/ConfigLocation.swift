import Foundation

enum ConfigLocation {
    static let appGroupID = "78K254QW6P.io.github.joemrk.FinderOpenIn"
    static let fileName = "commands.json"

    /// nil if the process lacks the entitlement for the group.
    static var configURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }
}
