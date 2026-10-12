import Foundation

struct Command: Codable, Equatable {
    let title: String
    let cmd: [String]
}

enum ConfigError: Error, Equatable {
    case missing
    case unreadable(String)
    case invalid(String)
}

enum ConfigLoader {
    static func load(from url: URL) -> Result<[Command], ConfigError> {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .failure(.missing)
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
        return parse(data)
    }

    static func parse(_ data: Data) -> Result<[Command], ConfigError> {
        let decoded: [Command]
        do {
            decoded = try JSONDecoder().decode([Command].self, from: data)
        } catch {
            return .failure(.invalid(String(describing: error)))
        }

        var seen = Set<String>()
        var commands: [Command] = []
        for (index, command) in decoded.enumerated() {
            if command.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure(.invalid("command #\(index): empty title"))
            }
            guard let executable = command.cmd.first, !executable.isEmpty else {
                return .failure(.invalid("command #\(index) (\(command.title)): empty cmd"))
            }
            guard seen.insert(command.title).inserted else {
                Log.config.error("duplicate title \(command.title, privacy: .public) at #\(index); keeping the first")
                continue
            }
            commands.append(command)
        }
        return .success(commands)
    }
}
