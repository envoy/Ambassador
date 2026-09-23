//
//  DataResponseTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class DataResponseTests: XCTestCase {
    func testDataResponse() {
        var receivedEnviron: [String: Any]?
        let dataResponse = DataResponse(
            statusCode: 201,
            statusMessage: "created",
            contentType: "application/my-format",
            headers: [
                ("X-Foo-Bar", "header")
            ]
        ) { (environ) -> Data in
            receivedEnviron = environ
            return Data("hello".utf8)
        }

        let recorder = ResponseRecorder()

        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        dataResponse.app(
            environ,
            startResponse: recorder.startResponse,
            sendBody: recorder.sendBody
        )

        XCTAssertEqual(recorder.lastStatus, "201 created")
        XCTAssertEqual(recorder.lastHeader("Content-Type"), "application/my-format")
        XCTAssertEqual(Int(recorder.lastHeader("Content-Length") ?? "0"), "hello".count)
        XCTAssertEqual(recorder.lastHeader("X-Foo-Bar"), "header")

        XCTAssertEqual(recorder.bodies.count, 2)
        XCTAssertEqual(recorder.bodies.first ?? Data(), Data("hello".utf8))
        XCTAssertEqual(recorder.bodies.last?.count, 0)

        XCTAssertEqual(receivedEnviron?.count, environ.count)
        for (key, value) in environ {
            XCTAssertEqual(receivedEnviron?[key] as? String, value as? String)
        }
    }

    func testCallerHeadersAreNotDuplicated() {
        let dataResponse = DataResponse(
            headers: [("content-type", "text/plain"), ("CONTENT-LENGTH", "99")]
        ) { _ in Data("hello".utf8) }

        let recorder = ResponseRecorder()
        dataResponse.app([:], startResponse: recorder.startResponse, sendBody: recorder.sendBody)

        XCTAssertEqual(recorder.lastHeaders.map(\.0), ["content-type", "CONTENT-LENGTH"])
        XCTAssertEqual(recorder.lastHeader("Content-Type"), "text/plain")
        XCTAssertEqual(recorder.lastHeader("Content-Length"), "99")
    }

    func testDataResponseWithEmptyData() {
        let dataResponse = DataResponse()

        let recorder = ResponseRecorder()

        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        dataResponse.app(
            environ,
            startResponse: recorder.startResponse,
            sendBody: recorder.sendBody
        )

        XCTAssertEqual(recorder.bodies.count, 1)
        XCTAssertEqual(recorder.bodies.first?.count, 0)
    }
}
