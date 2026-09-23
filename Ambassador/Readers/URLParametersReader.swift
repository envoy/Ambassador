//
//  URLParametersReader.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public enum URLParametersReader {
    public enum LocalError: Error {
        case utf8EncodingError
    }

    /// Read all data into bytes array and parse it as URL parameter
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter errorHandler: the handler to be called when failed to read URL parameters. When
    ///                            `nil`, the failure is logged to standard error.
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as URL
    ///                       parameter
    public static func read(
        _ input: SWSGIInput,
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping (([(String, String)]) -> Void)
    ) {
        read(input, errorHandler: errorHandler, log: DataReader.logToStandardError, handler: handler)
    }

    /// Read the request body from `environ["swsgi.input"]` and parse it as URL parameters
    ///  - Parameter environ: the SWSGI environ of the request
    ///  - Parameter errorHandler: the handler to be called when failed to read URL parameters. When
    ///                            `nil`, the failure is logged to standard error.
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as URL
    ///                       parameter
    public static func read(
        _ environ: [String: Any],
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping (([(String, String)]) -> Void)
    ) {
        read(environ.swsgi.input, errorHandler: errorHandler, handler: handler)
    }

    /// Read the request body from `environ["swsgi.input"]` and parse it as URL parameters with
    /// lookup by key
    ///  - Parameter environ: the SWSGI environ of the request
    ///  - Parameter errorHandler: the handler to be called when failed to read URL parameters. When
    ///                            `nil`, the failure is logged to standard error.
    ///  - Parameter handler: the handler to be called with the parsed parameters
    public static func readParameters(
        _ environ: [String: Any],
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping ((FormParameters) -> Void)
    ) {
        read(environ, errorHandler: errorHandler) { handler(FormParameters($0)) }
    }

    static func read(
        _ input: SWSGIInput,
        errorHandler: ((Error) -> Void)?,
        log: @escaping (String) -> Void,
        handler: @escaping (([(String, String)]) -> Void)
    ) {
        DataReader.decode(
            input,
            reader: "URLParametersReader",
            errorHandler: errorHandler,
            log: log,
            decode: { data in
                guard let string = String(bytes: data, encoding: .utf8) else {
                    throw LocalError.utf8EncodingError
                }
                return parseURLParameters(string)
            },
            handler: handler
        )
    }

    /// Parse given string as URL parameters
    ///  - Parameter string: URL encoded parameter string to parse
    ///  - Returns: array of (key, value) pairs of URL encoded parameters
    public static func parseURLParameters(_ string: String) -> [(String, String)] {
        let parameters = string.components(separatedBy: "&")
        return parameters.map { parameter in
            let parts = parameter.components(separatedBy: "=")
            let key = parts[0]
            let value = Array(parts[1..<parts.count]).joined(separator: "=")
            return (
                key.removingPercentEncoding ?? key,
                value.removingPercentEncoding ?? value
            )
        }
    }
}
