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
        let input = { (handler: ([UInt8] -> Void)?) in
            handler!(Array("{ ".utf8))
            handler!(Array("\"name\"".utf8))
            handler!(Array(":".utf8))
            handler!(Array("\"heisenberg\"".utf8))
            handler!(Array("} ".utf8))
            handler!([])
        }
        var receivedData: [AnyObject] = []
        JSONReader.read(input) { data in
            receivedData.append(data)
        }
        XCTAssertEqual(receivedData.count, 1)
        let dict = receivedData.first as? [String: String]
        XCTAssertEqual(dict?.count, 1)
        XCTAssertEqual(dict?["name"], "heisenberg")
    }
}
