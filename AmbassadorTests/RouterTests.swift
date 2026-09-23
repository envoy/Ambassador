//
//  RouterTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class RouterTests: XCTestCase {
    func testRouter() {
        let router = Router()
        router["/path/to/1"] = DataResponse() { environ -> Data in
            return Data("hello".utf8)
        }

        let recorder = ResponseRecorder()
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        router.app(
            environ,
            startResponse: recorder.startResponse,
            sendBody: recorder.sendBody
        )
        XCTAssertEqual(recorder.statuses.count, 1)
        XCTAssertEqual(recorder.lastStatus, "404 Not found")
        XCTAssertEqual(recorder.bodies.count, 1)
        XCTAssertEqual(recorder.bodies.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/path/to/1",
        ]
        router.app(
            environ2,
            startResponse: recorder.startResponse,
            sendBody: recorder.sendBody
        )
        XCTAssertEqual(recorder.statuses.count, 2)
        XCTAssertEqual(recorder.lastStatus, "200 OK")
        XCTAssertEqual(recorder.bodies.count, 3)
        XCTAssertEqual(String(bytes: recorder.bodies[1], encoding: String.Encoding.utf8), "hello")
        XCTAssertEqual(recorder.bodies.last?.count, 0)
    }

    func testRegularExpressionRouting() {
        let router = Router()
        var receivedCaptures: [String]?
        let emailRoute = "/activate/email/([a-zA-Z0-9]+@[a-zA-Z0-9]+\\.[a-zA-Z0-9]+)" +
            "/code/([a-zA-Z0-9]+)"
        router[emailRoute] = DataResponse() { environ -> Data in
            receivedCaptures = environ["ambassador.router_captures"] as? [String]
            return Data("email".utf8)
        }
        router["/foo"] = DataResponse() { environ -> Data in
            return Data("foo".utf8)
        }

        let recorder = ResponseRecorder()
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/egg",
        ]
        router.app(
            environ,
            startResponse: recorder.startResponse,
            sendBody: recorder.sendBody
        )
        XCTAssertEqual(recorder.statuses.count, 1)
        XCTAssertEqual(recorder.lastStatus, "404 Not found")
        XCTAssertEqual(recorder.bodies.count, 1)
        XCTAssertEqual(recorder.bodies.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/activate/email/fang@envoy.com/code/ABCD1234",
        ]
        router.app(
            environ2,
            startResponse: recorder.startResponse,
            sendBody: recorder.sendBody
        )
        XCTAssertEqual(recorder.statuses.count, 2)
        XCTAssertEqual(recorder.lastStatus, "200 OK")
        XCTAssertEqual(recorder.bodies.count, 3)
        XCTAssertEqual(String(bytes: recorder.bodies[1], encoding: String.Encoding.utf8), "email")
        XCTAssertEqual(recorder.bodies.last?.count, 0)
        XCTAssertEqual(receivedCaptures ?? [], ["fang@envoy.com", "ABCD1234"])
    }
    func testNonASCIIPathMatchesWholePath() {
        let router = Router()
        let recorder = CaptureRecorder()
        router["/items/(.+)/end$"] = recorder.app

        XCTAssertEqual(dispatch(router, path: "/items/café😀/end"), "200 OK")
        XCTAssertEqual(recorder.captures, ["café😀"])
    }

    func testUnmatchedOptionalCaptureGroupIsEmptyString() {
        let router = Router()
        let recorder = CaptureRecorder()
        router["^/users(/admin)?/(\\d+)$"] = recorder.app

        XCTAssertEqual(dispatch(router, path: "/users/42"), "200 OK")
        XCTAssertEqual(recorder.captures, ["", "42"])
    }

    func testAssigningNilRemovesRoute() {
        let router = Router()
        router["/foo"] = DataResponse()
        XCTAssertEqual(dispatch(router, path: "/foo"), "200 OK")

        router["/foo"] = nil
        XCTAssertNil(router["/foo"])
        XCTAssertEqual(dispatch(router, path: "/foo"), "404 Not found")
    }

    func testConcurrentRegistrationAndDispatch() {
        // Router isn't Sendable (it's an open class), but consumers share it across threads on
        // purpose: routes are registered from the test thread while the event loop dispatches.
        // This test exercises exactly that, so opt out of the compile-time check.
        nonisolated(unsafe) let router = Router()
        router["^/stable$"] = DataResponse()

        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            if index.isMultiple(of: 2) {
                router["^/route/\(index)$"] = DataResponse()
            } else {
                XCTAssertEqual(dispatch(router, path: "/stable"), "200 OK")
            }
        }
    }
}

private final class CaptureRecorder {
    var captures: [String]?

    var app: WebApp {
        DataResponse { environ -> Data in
            self.captures = environ["ambassador.router_captures"] as? [String]
            return Data()
        }
    }
}

private func dispatch(_ router: Router, path: String) -> String? {
    let recorder = ResponseRecorder()
    router.app(
        ["REQUEST_METHOD": "GET", "SCRIPT_NAME": "", "PATH_INFO": path],
        startResponse: recorder.startResponse,
        sendBody: recorder.sendBody
    )
    return recorder.lastStatus
}
