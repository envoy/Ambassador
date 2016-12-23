//
//  JSONReaderTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

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
}
