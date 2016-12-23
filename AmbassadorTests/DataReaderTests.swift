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
        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("hello ".utf8))
            handler!(Data("baby".utf8))
            handler!(Data())
        }
        var receivedData = [Data]()
        DataReader.read(input) { data in
            receivedData.append(data)
        }
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.first ?? Data(), Data("hello baby".utf8))
    }
}
