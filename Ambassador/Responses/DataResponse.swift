//
//  DataResponse.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Data response responses data from given handler immediately to the client
public struct DataResponse: WebApp {
    /// The status code to response
    public let statusCode: Int
    /// The status message to response
    public let statusMessage: String
    /// Headers to response
    public let headers: [(String, String)]
    /// Produces the body: called with the request environ and a `sendData` to call exactly once
    /// with the whole payload
    public let handler: (_ environ: [String: Any], _ sendData: @escaping (Data) -> Void) -> Void
    /// The Content type to response
    public let contentType: String

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/octet-stream",
        headers: [(String, String)] = [],
        handler: @escaping (_ environ: [String: Any], _ sendData: @escaping (Data) -> Void) -> Void
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.contentType = contentType
        self.headers = headers
        self.handler = handler
    }

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/octet-stream",
        headers: [(String, String)] = [],
        handler: ((_ environ: [String: Any]) -> Data)? = nil
    ) {
        self.init(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            sendData(handler?(environ) ?? Data())
        }
    }

    public func app(
        _ environ: [String: Any],
        startResponse: @escaping SWSGIStartResponse,
        sendBody: @escaping SWSGISendBody
    ) {
        handler(environ) { data in
            // add the defaults only when the caller didn't supply them (header names are case-insensitive)
            var headers = self.headers
            if !headers.contains(named: "Content-Type") {
                headers.append(("Content-Type", self.contentType))
            }
            if !headers.contains(named: "Content-Length") {
                headers.append(("Content-Length", String(data.count)))
            }

            startResponse("\(self.statusCode) \(self.statusMessage)", headers)
            if !data.isEmpty {
                sendBody(data)
            }
            sendBody(Data())
        }
    }
}

extension [(String, String)] {
    /// Whether a header called `name` is present, compared case-insensitively
    func contains(named name: String) -> Bool {
        contains { $0.0.caseInsensitiveCompare(name) == .orderedSame }
    }
}
