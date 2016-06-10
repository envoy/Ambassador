//
//  DataReaderTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class DataReaderTests: XCTestCase {
    func testDataReader() {
        let input = { (handler: ([UInt8] -> Void)?) in
            handler!(Array("hello ".utf8))
            handler!(Array("baby".utf8))
            handler!([])
        }
        var receivedData: [[UInt8]] = []
        DataReader.read(input) { data in
            receivedData.append(data)
        }
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.first ?? [], Array("hello baby".utf8))
    }
}
