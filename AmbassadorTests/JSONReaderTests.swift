//
//  JSONReaderTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Ambassador
import Embassy

class JSONReaderTests: XCTestCase {
    func testJSONReader() {
        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("{ ".utf8))
            handler!(Data("\"name\"".utf8))
            handler!(Data(":".utf8))
            handler!(Data("\"heisenberg\"".utf8))
            handler!(Data("} ".utf8))
            handler!(Data())
        }
        var receivedData: [Any] = []
        JSONReader.read(input) { data in
            receivedData.append(data)
        }
        XCTAssertEqual(receivedData.count, 1)
        let dict = receivedData.first as? [String: String]
        XCTAssertEqual(dict?.count, 1)
        XCTAssertEqual(dict?["name"], "heisenberg")
    }

    func testInvalidJSONWithoutErrorHandlerLogs() {
        var logged: [String] = []
        var handlerCalled = false
        JSONReader.read(
            input(of: "not json"),
            errorHandler: nil,
            log: { logged.append($0) },
            handler: { _ in handlerCalled = true }
        )
        XCTAssertFalse(handlerCalled)
        XCTAssertEqual(logged.count, 1)
        XCTAssertTrue(logged[0].hasPrefix("Ambassador: JSONReader failed to parse request body (8 bytes): "))
        XCTAssertTrue(logged[0].hasSuffix("Handler not called; no response will be sent."))
    }

    func testInvalidJSONWithErrorHandlerDoesNotLog() {
        var logged: [String] = []
        var receivedError: Error?
        JSONReader.read(
            input(of: "not json"),
            errorHandler: { receivedError = $0 },
            log: { logged.append($0) },
            handler: { _ in XCTFail("handler should not be called") }
        )
        XCTAssertNotNil(receivedError)
        XCTAssertTrue(logged.isEmpty)
    }
}

private func input(of body: String) -> SWSGIInput {
    return { handler in
        handler!(Data(body.utf8))
        handler!(Data())
    }
}
