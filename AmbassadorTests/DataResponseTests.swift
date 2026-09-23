//
//  DataResponseTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Embassy
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
        let headersDict = MultiDictionary<String, String, LowercaseKeyTransform>(
            items: recorder.lastHeaders
        )
        XCTAssertEqual(headersDict["Content-Type"], "application/my-format")
        XCTAssertEqual(Int(headersDict["Content-Length"] ?? "0"), "hello".count)
        XCTAssertEqual(headersDict["X-Foo-Bar"], "header")

        XCTAssertEqual(recorder.bodies.count, 2)
        XCTAssertEqual(recorder.bodies.first ?? Data(), Data("hello".utf8))
        XCTAssertEqual(recorder.bodies.last?.count, 0)

        XCTAssertEqual(receivedEnviron?.count, environ.count)
        for (key, value) in environ {
            XCTAssertEqual(receivedEnviron?[key] as? String, value as? String)
        }
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
