//
//  URLParametersReaderTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class URLParametersReaderTests: XCTestCase {
    func testParseURLParameter() {
        let params1 = URLParametersReader.parseURLParameters("foo=bar&eggs=spam")
        XCTAssertEqual(params1.count, 2)
        XCTAssertEqual(params1.first?.0, "foo")
        XCTAssertEqual(params1.first?.1, "bar")
        XCTAssertEqual(params1.last?.0, "eggs")
        XCTAssertEqual(params1.last?.1, "spam")

        let params2 = URLParametersReader.parseURLParameters("foo%5Bbar%5D=eggs%20spam")
        XCTAssertEqual(params2.count, 1)
        XCTAssertEqual(params2.first?.0, "foo[bar]")
        XCTAssertEqual(params2.first?.1, "eggs spam")
    }

    func testURLParameterReader() {
        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("foo".utf8))
            handler!(Data("=".utf8))
            handler!(Data("bar".utf8))
            handler!(Data("&eggs=spam".utf8))
            handler!(Data())
        }
        var receivedParams: [(String, String)]!
        URLParametersReader.read(input) { params in
            receivedParams = params
        }
        XCTAssertEqual(receivedParams.count, 2)
        XCTAssertEqual(receivedParams.first?.0, "foo")
        XCTAssertEqual(receivedParams.first?.1, "bar")
        XCTAssertEqual(receivedParams.last?.0, "eggs")
        XCTAssertEqual(receivedParams.last?.1, "spam")
    }
}
