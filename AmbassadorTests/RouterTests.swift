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

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/path/to/1",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "hello")
        XCTAssertEqual(receivedData.last?.count, 0)
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

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/egg",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/activate/email/fang@envoy.com/code/ABCD1234",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "email")
        XCTAssertEqual(receivedData.last?.count, 0)
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
    var status: String?
    router.app(
        ["REQUEST_METHOD": "GET", "SCRIPT_NAME": "", "PATH_INFO": path],
        startResponse: { receivedStatus, _ in status = receivedStatus },
        sendBody: { _ in }
    )
    return status
}
