import XCTest

final class CommandTemplateTests: XCTestCase {
    static let nastyPaths = [
        "/tmp/plain",
        "/tmp/with space/dir",
        "/tmp/it's",
        "/tmp/say \"hi\"",
        "/tmp/$HOME/`whoami`/$(id)",
        "/tmp/a;b&&c|d>e",
        "/tmp/тест/日本語/🙂",
        "/tmp/star*/q?/[x]",
        "/tmp/back\\slash",
        "/tmp/-leading-dash",
        "/tmp/line\nbreak",
    ]

    func testReplacesWholeToken() {
        XCTAssertEqual(CommandTemplate.expand(["agy", "{path}"], path: "/tmp/x"), ["agy", "/tmp/x"])
    }

    func testReplacesInsideToken() {
        XCTAssertEqual(CommandTemplate.expand(["tool", "--dir={path}"], path: "/tmp/x"), ["tool", "--dir=/tmp/x"])
    }

    func testReplacesEveryOccurrence() {
        XCTAssertEqual(CommandTemplate.expand(["cp", "{path}", "{path}.bak", "{path}:{path}"], path: "/a"),
                       ["cp", "/a", "/a.bak", "/a:/a"])
    }

    func testCommandWithoutPlaceholderIsUnchanged() {
        XCTAssertEqual(CommandTemplate.expand(["open", "-a", "Zed"], path: "/tmp/x"), ["open", "-a", "Zed"])
    }

    func testNastyPathsStayOneTokenAndUnchanged() {
        for path in Self.nastyPaths {
            let argv = CommandTemplate.expand(["ide", "--flag", "{path}"], path: path)
            XCTAssertEqual(argv.count, 3, path)
            XCTAssertEqual(argv[2], path)
        }
    }

    func testPathContainingPlaceholderIsNotExpandedTwice() {
        XCTAssertEqual(CommandTemplate.expand(["ide", "{path}"], path: "/tmp/{path}/x"), ["ide", "/tmp/{path}/x"])
    }
}
