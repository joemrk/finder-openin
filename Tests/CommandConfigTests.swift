import XCTest

final class CommandConfigTests: XCTestCase {
    private func parse(_ json: String) -> Result<[Command], ConfigError> {
        ConfigLoader.parse(Data(json.utf8))
    }

    private func assertInvalid(_ json: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(.invalid) = parse(json) else {
            return XCTFail("expected .invalid for: \(json)", file: file, line: line)
        }
    }

    func testParsesValidConfig() {
        let result = parse(#"[{"title":"Antigravity","cmd":["agy","{path}"]},{"title":"VS Code","cmd":["code","{path}"]}]"#)
        XCTAssertEqual(try result.get(), [
            Command(title: "Antigravity", cmd: ["agy", "{path}"]),
            Command(title: "VS Code", cmd: ["code", "{path}"]),
        ])
    }

    func testEmptyArrayIsValid() {
        XCTAssertEqual(try parse("[]").get(), [])
    }

    func testIgnoresUnknownFields() {
        XCTAssertEqual(try parse(#"[{"title":"A","cmd":["a"],"icon":"x"}]"#).get(),
                       [Command(title: "A", cmd: ["a"])])
    }

    func testMissingFieldsAreInvalid() {
        assertInvalid(#"[{"title":"A"}]"#)
        assertInvalid(#"[{"cmd":["a"]}]"#)
    }

    func testEmptyTitleOrCmdIsInvalid() {
        assertInvalid(#"[{"title":"","cmd":["a"]}]"#)
        assertInvalid(#"[{"title":"   ","cmd":["a"]}]"#)
        assertInvalid(#"[{"title":"A","cmd":[]}]"#)
        assertInvalid(#"[{"title":"A","cmd":["","x"]}]"#)
    }

    func testWrongTypesAreInvalid() {
        assertInvalid(#"[{"title":1,"cmd":["a"]}]"#)
        assertInvalid(#"[{"title":"A","cmd":"a {path}"}]"#)
    }

    // Typical hand-editing mistakes. A trailing comma in the array is not one of them:
    // JSONDecoder accepts it, and the config loads correctly.
    func testHandEditMistakesAreInvalid() {
        assertInvalid(#"[{"title":"A","cmd":["a"]} {"title":"B","cmd":["b"]}]"#)
        assertInvalid(#"{"title":"A","cmd":["a"]}"#)
        assertInvalid("")
        assertInvalid("not json")
    }

    func testDuplicateTitlesKeepFirst() {
        let result = parse(#"[{"title":"A","cmd":["first"]},{"title":"B","cmd":["b"]},{"title":"A","cmd":["second"]}]"#)
        XCTAssertEqual(try result.get(), [
            Command(title: "A", cmd: ["first"]),
            Command(title: "B", cmd: ["b"]),
        ])
    }

    func testMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("commands.json")
        XCTAssertEqual(ConfigLoader.load(from: url), .failure(.missing))
    }

    func testLoadsFromFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("commands.json")
        try Data(#"[{"title":"Zed","cmd":["zed","{path}"]}]"#.utf8).write(to: url)
        XCTAssertEqual(try ConfigLoader.load(from: url).get(), [Command(title: "Zed", cmd: ["zed", "{path}"])])
    }

    func testDirectoryInsteadOfFileIsUnreadable() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        guard case .failure(.unreadable) = ConfigLoader.load(from: dir) else {
            return XCTFail("expected .unreadable")
        }
    }
}
