//
//  JSONResponse.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A response app for responding JSON data
public struct JSONResponse: WebApp {
    /// Underlying data response; every initializer ends up here
    let dataResponse: DataResponse

    private init(dataResponse: DataResponse) {
        self.dataResponse = dataResponse
    }

    /// The one place JSON is serialized
    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: JSONSerialization.WritingOptions = .prettyPrinted,
        headers: [(String, String)] = [],
        handler: @escaping (_ environ: [String: Any], _ sendJSON: @escaping (Any) -> Void) -> Void
    ) {
        self.init(dataResponse: DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            handler(environ) { json in
                sendData(try! JSONSerialization.data(withJSONObject: json, options: jsonWritingOptions))
            }
        })
    }

    /// With no `handler`, the body is empty (nothing is serialized)
    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: JSONSerialization.WritingOptions = .prettyPrinted,
        headers: [(String, String)] = [],
        handler: ((_ environ: [String: Any]) -> Any)? = nil
    ) {
        guard let handler else {
            self.init(dataResponse: DataResponse(
                statusCode: statusCode,
                statusMessage: statusMessage,
                contentType: contentType,
                headers: headers
            ))
            return
        }
        self.init(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            jsonWritingOptions: jsonWritingOptions,
            headers: headers,
            handler: { environ, sendJSON in sendJSON(handler(environ)) }
        )
    }

    /// Respond with `json`, serialized with `JSONSerialization`. `json` is evaluated on every
    /// request, like a handler's body, so it can read state that changes after the route is set.
    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: JSONSerialization.WritingOptions = .prettyPrinted,
        headers: [(String, String)] = [],
        json: @autoclosure @escaping () -> Any
    ) {
        self.init(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            jsonWritingOptions: jsonWritingOptions,
            headers: headers,
            handler: { _ in json() }
        )
    }

    /// Respond with `value`, encoded with `encoder`. `value` is evaluated on every request, like a
    /// handler's body, so it can read state that changes after the route is set.
    public init<Value: Encodable>(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        headers: [(String, String)] = [],
        encoding value: @autoclosure @escaping () -> Value,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.init(dataResponse: DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { _ in
            try! encoder.encode(value())
        })
    }

    public func app(
        _ environ: [String: Any],
        startResponse: @escaping SWSGIStartResponse,
        sendBody: @escaping SWSGISendBody
    ) {
        return dataResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }
}
