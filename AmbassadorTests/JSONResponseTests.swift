//
//  JSONResponseTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Embassy
import Ambassador

class JSONResponseTests: XCTestCase {
    func testJSONResponse() {
        let dataResponse = JSONResponse() { (environ) -> AnyObject in
            return ["foo", "bar"]
        }

        var receivedStatus: String?
        var receivedHeaders: [(String, String)]?
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus = status
            receivedHeaders = headers
        }

        var receivedData: [[UInt8]] = []
        let sendBody = { (data: [UInt8]) in
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

        XCTAssertEqual(receivedStatus, "200 OK")
        let headersDict = MultiDictionary<String, String, LowercaseKeyTransform>(
            items: receivedHeaders ?? []
        )
        XCTAssertEqual(headersDict["Content-Type"], "application/json")

        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(receivedData.last?.count, 0)
        let bytes = receivedData.first ?? []
        let parsedJSON: [String] = try! NSJSONSerialization.JSONObjectWithData(
            NSData(bytes: bytes, length: bytes.count),
            options: .AllowFragments
        ) as? [String] ?? []
        XCTAssertEqual(parsedJSON, ["foo", "bar"])
    }

}
