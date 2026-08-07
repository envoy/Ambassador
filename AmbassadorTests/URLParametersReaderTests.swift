//
//  URLParametersReaderTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Ambassador

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

    func testInvalidUTF8WithoutErrorHandlerLogs() {
        var logged: [String] = []
        let invalidUTF8: SWSGIInput = { handler in
            handler!(Data([0xFF, 0xFE]))
            handler!(Data())
        }
        URLParametersReader.read(
            invalidUTF8,
            errorHandler: nil,
            log: { logged.append($0) },
            handler: { _ in XCTFail("handler should not be called") }
        )
        XCTAssertEqual(logged.count, 1)
        XCTAssertTrue(logged[0].hasPrefix("Ambassador: URLParametersReader failed to parse request body (2 bytes): "))
    }

    // MARK: - Helpers

    /// Tuples aren't Equatable, so compare pair-by-pair and report which pair diverged.
    private func assertParams(
        _ input: String,
        _ expected: [(String, String)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = URLParametersReader.parseURLParameters(input)
        XCTAssertEqual(
            actual.count,
            expected.count,
            "pair count for \(input.debugDescription)",
            file: file,
            line: line
        )
        for (index, pair) in zip(actual, expected).enumerated() {
            XCTAssertEqual(
                pair.0.0,
                pair.1.0,
                "key \(index) for \(input.debugDescription)",
                file: file,
                line: line
            )
            XCTAssertEqual(
                pair.0.1,
                pair.1.1,
                "value \(index) for \(input.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    func testParseURLParametersPreservedBehavior() {
        assertParams("foo=bar&eggs=spam", [("foo", "bar"), ("eggs", "spam")])
        assertParams("foo%5Bbar%5D=eggs%20spam", [("foo[bar]", "eggs spam")])

        // A key with no `=` yields an empty value.
        assertParams("foo", [("foo", "")])
        assertParams("foo=", [("foo", "")])
        assertParams("=bar", [("", "bar")])

        // Only the first `=` is a delimiter.
        assertParams("foo=a=b", [("foo", "a=b")])

        // `+` is NOT form-decoded to a space.
        assertParams("a+b=c+d", [("a+b", "c+d")])

        // Duplicate keys keep their order.
        assertParams("foo=a&foo=b", [("foo", "a"), ("foo", "b")])

        // Empty segments produce empty pairs.
        assertParams("foo=a&&b=c", [("foo", "a"), ("", ""), ("b", "c")])
        assertParams("foo=a&b", [("foo", "a"), ("b", "")])

        // Non-ASCII, both escaped and raw.
        assertParams("foo=caf%C3%A9", [("foo", "café")])
        assertParams("foo=café", [("foo", "café")])
        assertParams("foo=👍", [("foo", "👍")])

        // Malformed escapes are left alone rather than dropped.
        assertParams("foo=%ZZ", [("foo", "%ZZ")])
        assertParams("foo=100%", [("foo", "100%")])
        assertParams("foo=a%2", [("foo", "a%2")])

        // `#` and `?` are data in a form body, not URL delimiters.
        assertParams("foo=a#b", [("foo", "a#b")])
        assertParams("a=1&b=2#frag", [("a", "1"), ("b", "2#frag")])
        assertParams("foo=a?b", [("foo", "a?b")])

        // An unencoded character must not disable decoding for the rest of the body.
        assertParams("a b=c%20d", [("a b", "c d")])
        assertParams("foo=a b&x%5By%5D=z", [("foo", "a b"), ("x[y]", "z")])
    }

    /// An empty body has no parameters. The old parser reported a phantom `("", "")`.
    func testParseURLParametersEmptyString() {
        assertParams("", [])
    }

    /// A stray `%` no longer discards decoding for the whole field — only that
    /// character is treated as literal. The old parser returned `("x", "%%20")`.
    func testParseURLParametersLonePercentStillDecodesRemainingEscapes() {
        assertParams("x=%%20", [("x", "% ")])
    }
}
