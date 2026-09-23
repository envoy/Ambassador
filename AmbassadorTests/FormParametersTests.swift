//
//  FormParametersTests.swift
//  Ambassador
//

import Foundation
import Testing

import Ambassador

@Suite struct FormParametersTests {
    @Test func lookupByKey() {
        let params = FormParameters(parsing: "foo=bar&eggs=spam&foo=baz&name=walter%20white")

        #expect(params["foo"] == "bar")
        #expect(params.values(for: "foo") == ["bar", "baz"])
        #expect(params["name"] == "walter white")
        #expect(params["missing"] == nil)
        #expect(params.values(for: "missing").isEmpty)
        #expect(params["FOO"] == nil, "keys are case-sensitive")
    }

    @Test func iterationKeepsOrder() {
        let params = FormParameters(parsing: "b=2&a=1&b=3")

        #expect(params.map(\.0) == ["b", "a", "b"])
        #expect(params.map(\.1) == ["2", "1", "3"])
        #expect(params.items.count == 3)
    }

    @Test func readParametersFromEnviron() throws {
        let input: SWSGIInput = { handler in
            handler!(Data("code=abc".utf8))
            handler!(Data("&state=xyz".utf8))
            handler!(Data())
        }
        var received: FormParameters?
        URLParametersReader.readParameters(["swsgi.input": input]) { received = $0 }

        let params = try #require(received)
        #expect(params["code"] == "abc")
        #expect(params["state"] == "xyz")
    }

    @Test func queryParameters() {
        let environ: [String: Any] = ["QUERY_STRING": "page=2&sort=name"]

        #expect(environ.swsgi.queryParameters["page"] == "2")
        #expect(environ.swsgi.queryParameters["sort"] == "name")
    }

    @Test(arguments: [
        [:],
        ["QUERY_STRING": ""]
    ] as [[String: String]])
    func queryParametersEmptyWithoutQueryString(environ: [String: String]) {
        let environ: [String: Any] = environ
        #expect(environ.swsgi.queryParameters.items.isEmpty)
    }
}
