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

        var receivedStatus: String?
        var receivedHeaders: [(String, String)]?
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus = status
            receivedHeaders = headers
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
        dataResponse.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )

        XCTAssertEqual(receivedStatus, "201 created")
        let headersDict = MultiDictionary<String, String, LowercaseKeyTransform>(
            items: receivedHeaders ?? []
        )
        XCTAssertEqual(headersDict["Content-Type"], "application/my-format")
        XCTAssertEqual(Int(headersDict["Content-Length"] ?? "0"), "hello".count)
        XCTAssertEqual(headersDict["X-Foo-Bar"], "header")

        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(receivedData.first ?? Data(), Data("hello".utf8))
        XCTAssertEqual(receivedData.last?.count, 0)

        XCTAssertEqual(receivedEnviron?.count, environ.count)
        for (key, value) in environ {
            XCTAssertEqual(receivedEnviron?[key] as? String, value as? String)
        }
    }

    func testDataResponseWithEmptyData() {
        let dataResponse = DataResponse()

        let startResponse = { (status: String, headers: [(String, String)]) in
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
        dataResponse.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )

        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.first?.count, 0)
    }
}
