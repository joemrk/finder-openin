import Foundation

struct RunRequest: Equatable {
    static let scheme = "finderopenin"
    static let host = "run"

    let id: String
    let path: String

    init(id: String, path: String) {
        self.id = id
        self.path = path
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              components.host == Self.host,
              let items = components.queryItems,
              let id = items.first(where: { $0.name == "id" })?.value, !id.isEmpty,
              let path = items.first(where: { $0.name == "path" })?.value, !path.isEmpty
        else { return nil }
        self.id = id
        self.path = path
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "path", value: path),
        ]
        // scheme + host + query always produce a valid URL.
        return components.url!
    }

    /// One selected item → the item itself; otherwise the window's folder.
    static func targetPath(selected: [URL], targeted: URL?) -> String? {
        if selected.count == 1 { return selected[0].path }
        return targeted?.path
    }
}
