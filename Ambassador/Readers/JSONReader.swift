//
//  JSONReader.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public struct JSONReader {
    /// Read all data into bytes array and parse it as JSON
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter errorHandler: the handler to be called parsing JSON failed. When `nil`, the
    ///                            failure is logged to standard error.
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as JSON
    public static func read(
        _ input: SWSGIInput,
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping ((Any) -> Void)
    ) {
        read(input, errorHandler: errorHandler, log: DataReader.logToStandardError, handler: handler)
    }

    /// Read the request body from `environ["swsgi.input"]` and parse it as JSON
    ///  - Parameter environ: the SWSGI environ of the request
    ///  - Parameter errorHandler: the handler to be called parsing JSON failed. When `nil`, the
    ///                            failure is logged to standard error.
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as JSON
    public static func read(
        _ environ: [String: Any],
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping ((Any) -> Void)
    ) {
        read(environ.swsgi.input, errorHandler: errorHandler, handler: handler)
    }

    static func read(
        _ input: SWSGIInput,
        errorHandler: ((Error) -> Void)?,
        log: @escaping (String) -> Void,
        handler: @escaping ((Any) -> Void)
    ) {
        DataReader.read(input) { data in
            do {
                let json = try JSONSerialization.jsonObject(
                    with: data,
                    options: .allowFragments
                )
                handler(json)
            } catch {
                if let errorHandler = errorHandler {
                    errorHandler(error)
                } else {
                    DataReader.logReadFailure(reader: "JSONReader", byteCount: data.count, error: error, log: log)
                }
            }
        }
    }
}
