//
//  JSONResponseTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class JSONResponseTests: XCTestCase {
    func testJSONResponse() {
        let dataResponse = JSONResponse() { (environ) -> Any in
            return ["foo", "bar"]
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

        XCTAssertEqual(recorder.lastStatus, "200 OK")
        XCTAssertEqual(recorder.lastHeader("Content-Type"), "application/json")

        XCTAssertEqual(recorder.bodies.count, 2)
        XCTAssertEqual(recorder.bodies.last?.count, 0)
        let bytes = recorder.bodies.first ?? Data()
        let parsedJSON: [String] = try! JSONSerialization.jsonObject(
            with: bytes,
            options: .allowFragments
        ) as? [String] ?? []
        XCTAssertEqual(parsedJSON, ["foo", "bar"])
    }

}
