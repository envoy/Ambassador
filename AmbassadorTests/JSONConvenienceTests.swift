//
//  JSONConvenienceTests.swift
//  Ambassador
//

import Foundation
import Testing

@testable import Ambassador

@Suite struct JSONResponseConvenienceTests {
    @Test func jsonIsSerialized() throws {
        let response = JSONResponse(jsonWritingOptions: [], json: ["name": "heisenberg"])

        let body = try #require(send(response))
        #expect(body == #"{"name":"heisenberg"}"#)
    }

    @Test func jsonIsEvaluatedPerRequest() {
        let counter = Counter()
        let response = JSONResponse(json: ["count": counter.next()])

        #expect(counter.value == 0, "not evaluated when the route is created")
        _ = send(response)
        _ = send(response)
        #expect(counter.value == 2)
    }

    @Test func encodingUsesInjectedEncoder() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let user = User(firstName: "Walter", createdAt: Date(timeIntervalSince1970: 0))

        let body = try #require(send(JSONResponse(encoding: user, encoder: encoder)))
        #expect(body == #"{"created_at":"1970-01-01T00:00:00Z","first_name":"Walter"}"#)
    }

    @Test func encodingIsEvaluatedPerRequest() {
        let counter = Counter()
        let response = JSONResponse(encoding: counter.next())

        #expect(counter.value == 0)
        #expect(send(response) == "1")
        #expect(send(response) == "2")
    }

    @Test func existingHandlerFormsStillPickHandlerInit() {
        // A closure is itself an `Any`, so make sure these don't resolve to `json:`
        let sync = JSONResponse(jsonWritingOptions: []) { _ -> Any in ["a": 1] }
        #expect(send(sync) == #"{"a":1}"#)

        let async = JSONResponse(jsonWritingOptions: []) { _, sendJSON in sendJSON(["b": 2]) }
        #expect(send(async) == #"{"b":2}"#)

        #expect(send(JSONResponse(statusCode: 204)) == "")
    }
}

@Suite struct JSONReaderDecodeTests {
    @Test func decodesWithInjectedDecoder() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        var received: User?

        JSONReader.decode(
            User.self,
            from: environ(body: #"{"first_name":"Walter","created_at":"1970-01-01T00:00:00Z"}"#),
            decoder: decoder
        ) { received = $0 }

        let user = try #require(received)
        #expect(user == User(firstName: "Walter", createdAt: Date(timeIntervalSince1970: 0)))
    }

    @Test func failureGoesToErrorHandler() {
        var receivedError: Error?
        JSONReader.decode(
            User.self,
            from: environ(body: #"{"firstName":"Walter"}"#),
            errorHandler: { receivedError = $0 },
            handler: { _ in Issue.record("handler should not be called") }
        )
        #expect(receivedError is DecodingError)
    }

    @Test func failureWithoutErrorHandlerLogs() {
        var logged: [String] = []
        JSONReader.decode(
            from: input(of: "not json"),
            decoder: JSONDecoder(),
            errorHandler: nil,
            log: { logged.append($0) },
            handler: { (_: User) in Issue.record("handler should not be called") }
        )
        #expect(logged.count == 1)
        #expect(logged.first?.hasPrefix("Ambassador: JSONReader failed to parse request body (8 bytes): ") == true)
    }
}

private struct User: Codable, Equatable {
    var firstName: String
    var createdAt: Date
}

private final class Counter {
    private(set) var value = 0

    func next() -> Int {
        value += 1
        return value
    }
}

/// Runs `app` and returns the body as a string, or `nil` when no response started
private func send(_ app: WebApp) -> String? {
    let recorder = ResponseRecorder()
    app.app([:], startResponse: recorder.startResponse, sendBody: recorder.sendBody)
    guard recorder.lastStatus != nil else { return nil }
    return String(bytes: recorder.bodies.reduce(Data(), +), encoding: .utf8)
}

private func input(of body: String) -> SWSGIInput {
    { handler in
        handler!(Data(body.utf8))
        handler!(Data())
    }
}

private func environ(body: String) -> [String: Any] {
    ["swsgi.input": input(of: body)]
}
