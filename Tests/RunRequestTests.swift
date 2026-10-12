import XCTest

final class RunRequestTests: XCTestCase {
    func testURLShape() {
        let url = RunRequest(id: "Zed", path: "/tmp/x").url
        XCTAssertEqual(url.scheme, "finderopenin")
        XCTAssertEqual(url.host, "run")
    }

    func testRoundTripNastyPaths() {
        for path in CommandTemplateTests.nastyPaths {
            let request = RunRequest(id: "VS Code", path: path)
            XCTAssertEqual(RunRequest(url: request.url), request, path)
        }
    }

    // Characters that are significant in URLs.
    func testRoundTripURLMetacharacters() {
        let ids = ["C++ & Co=1", "100% #1?", "a+b c", "тест/IDE"]
        let paths = ["/tmp/a+b", "/tmp/a&b=c", "/tmp/50%/x#y?z", "/tmp/a b+c%20d"]
        for id in ids {
            for path in paths {
                let request = RunRequest(id: id, path: path)
                XCTAssertEqual(RunRequest(url: request.url), request, "\(id) | \(path)")
            }
        }
    }

    func testRejectsForeignURLs() {
        XCTAssertNil(RunRequest(url: URL(string: "https://run?id=A&path=/tmp")!))
        XCTAssertNil(RunRequest(url: URL(string: "finderopenin://other?id=A&path=/tmp")!))
        XCTAssertNil(RunRequest(url: URL(string: "finderopenin://run")!))
        XCTAssertNil(RunRequest(url: URL(string: "finderopenin://run?id=A")!))
        XCTAssertNil(RunRequest(url: URL(string: "finderopenin://run?path=/tmp")!))
        XCTAssertNil(RunRequest(url: URL(string: "finderopenin://run?id=&path=/tmp")!))
        XCTAssertNil(RunRequest(url: URL(string: "finderopenin://run?id=A&path=")!))
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertEqual(RunRequest(url: URL(string: "FinderOpenIn://run?id=A&path=/tmp")!),
                       RunRequest(id: "A", path: "/tmp"))
    }

    func testSingleSelectionWins() {
        let selected = [URL(fileURLWithPath: "/tmp/a b")]
        XCTAssertEqual(RunRequest.targetPath(selected: selected, targeted: URL(fileURLWithPath: "/tmp")), "/tmp/a b")
    }

    func testMultipleSelectionUsesTargetedFolder() {
        let selected = [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")]
        XCTAssertEqual(RunRequest.targetPath(selected: selected, targeted: URL(fileURLWithPath: "/tmp")), "/tmp")
    }

    func testNoSelectionUsesTargetedFolder() {
        XCTAssertEqual(RunRequest.targetPath(selected: [], targeted: URL(fileURLWithPath: "/tmp")), "/tmp")
    }

    func testNothingToTarget() {
        XCTAssertNil(RunRequest.targetPath(selected: [], targeted: nil))
        XCTAssertNil(RunRequest.targetPath(selected: [URL(fileURLWithPath: "/a"), URL(fileURLWithPath: "/b")], targeted: nil))
    }
}
