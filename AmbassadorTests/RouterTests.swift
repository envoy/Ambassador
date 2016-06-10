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
        router["/path/to/1"] = DataResponse() { environ -> [UInt8] in
            return Array("hello".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
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
        XCTAssertEqual(String(bytes: receivedData[1], encoding: NSUTF8StringEncoding), "hello")
        XCTAssertEqual(receivedData.last?.count, 0)
    }
}
