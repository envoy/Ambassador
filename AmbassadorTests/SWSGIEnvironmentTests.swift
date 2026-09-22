//
//  SWSGIEnvironmentTests.swift
//  Ambassador
//

import XCTest

import Ambassador
import Embassy

class SWSGIEnvironmentTests: XCTestCase {
    func testAccessors() {
        let environ: [String: Any] = [
            "REQUEST_METHOD": "POST",
            "PATH_INFO": "/api/v2/users/42",
            "QUERY_STRING": "page=2",
            "CONTENT_TYPE": "application/json",
            "HTTP_AUTHORIZATION": "Bearer token",
            "HTTP_X_REQUEST_ID": "abc",
            "ambassador.router_captures": ["42"]
        ]

        XCTAssertEqual(environ.swsgi.requestMethod, "POST")
        XCTAssertEqual(environ.swsgi.pathInfo, "/api/v2/users/42")
        XCTAssertEqual(environ.swsgi.queryString, "page=2")
        XCTAssertEqual(environ.swsgi.contentType, "application/json")
        XCTAssertEqual(environ.swsgi.routerCaptures, ["42"])
        XCTAssertEqual(environ.swsgi.header("Authorization"), "Bearer token")
        XCTAssertEqual(environ.swsgi.header("x-request-id"), "abc")
        XCTAssertNil(environ.swsgi.header("Cookie"))
    }

    func testMissingValues() {
        let environ: [String: Any] = [:]

        XCTAssertNil(environ.swsgi.requestMethod)
        XCTAssertNil(environ.swsgi.pathInfo)
        XCTAssertNil(environ.swsgi.queryString)
        XCTAssertNil(environ.swsgi.contentType)
        XCTAssertNil(environ.swsgi.eventLoop)
        XCTAssertEqual(environ.swsgi.routerCaptures, [])
    }

    func testRouterSetsCapturesReadableThroughAccessor() {
        let router = Router()
        var captures: [String]?
        router["^/users/(\\d+)$"] = DataResponse { environ -> Data in
            captures = environ.swsgi.routerCaptures
            return Data()
        }
        router.app(["PATH_INFO": "/users/7"], startResponse: { _, _ in }, sendBody: { _ in })
        XCTAssertEqual(captures, ["7"])
    }

    func testReadersAcceptEnviron() {
        var json: Any?
        JSONReader.read(environ(body: "{\"name\":\"heisenberg\"}")) { json = $0 }
        XCTAssertEqual((json as? [String: String])?["name"], "heisenberg")

        var params: [(String, String)]?
        URLParametersReader.read(environ(body: "foo=bar")) { params = $0 }
        XCTAssertEqual(params?.first?.0, "foo")
        XCTAssertEqual(params?.first?.1, "bar")

        var data: Data?
        DataReader.read(environ(body: "raw")) { data = $0 }
        XCTAssertEqual(data, Data("raw".utf8))
    }

    func testDelayedWrapsApp() {
        let delayed = DataResponse().delayed(.delay(seconds: 0.5))
        guard case .delay(let seconds) = delayed.delay else {
            return XCTFail("expected .delay, got \(delayed.delay)")
        }
        XCTAssertEqual(seconds, 0.5)
        XCTAssertTrue(delayed.delayedApp is DataResponse)

        guard case .random(let min, let max) = DataResponse().delayed().delay else {
            return XCTFail("expected default .random delay")
        }
        XCTAssertEqual(min, 0.1)
        XCTAssertEqual(max, 3)
    }
}

private func environ(body: String) -> [String: Any] {
    let input: SWSGIInput = { handler in
        handler!(Data(body.utf8))
        handler!(Data())
    }
    return ["swsgi.input": input]
}
