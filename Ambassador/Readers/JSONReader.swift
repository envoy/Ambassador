//
//  JSONReader.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public enum JSONReader {
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
        DataReader.decode(
            input,
            reader: "JSONReader",
            errorHandler: errorHandler,
            log: log,
            decode: { try JSONSerialization.jsonObject(with: $0, options: .allowFragments) },
            handler: handler
        )
    }

    /// Read all data and decode it as `type` with `JSONDecoder`
    ///  - Parameter type: the `Decodable` type to decode the body as
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter decoder: the decoder to use
    ///  - Parameter errorHandler: the handler to be called when decoding failed. When `nil`, the
    ///                            failure is logged to standard error.
    ///  - Parameter handler: the handler to be called with the decoded value
    public static func decode<Value: Decodable>(
        _ type: Value.Type,
        from input: SWSGIInput,
        decoder: JSONDecoder = JSONDecoder(),
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping (Value) -> Void
    ) {
        decode(
            from: input,
            decoder: decoder,
            errorHandler: errorHandler,
            log: DataReader.logToStandardError,
            handler: handler
        )
    }

    /// Read the request body from `environ["swsgi.input"]` and decode it as `type` with
    /// `JSONDecoder`
    ///  - Parameter type: the `Decodable` type to decode the body as
    ///  - Parameter environ: the SWSGI environ of the request
    ///  - Parameter decoder: the decoder to use
    ///  - Parameter errorHandler: the handler to be called when decoding failed. When `nil`, the
    ///                            failure is logged to standard error.
    ///  - Parameter handler: the handler to be called with the decoded value
    public static func decode<Value: Decodable>(
        _ type: Value.Type,
        from environ: [String: Any],
        decoder: JSONDecoder = JSONDecoder(),
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping (Value) -> Void
    ) {
        decode(type, from: environ.swsgi.input, decoder: decoder, errorHandler: errorHandler, handler: handler)
    }

    static func decode<Value: Decodable>(
        from input: SWSGIInput,
        decoder: JSONDecoder,
        errorHandler: ((Error) -> Void)?,
        log: @escaping (String) -> Void,
        handler: @escaping (Value) -> Void
    ) {
        DataReader.decode(
            input,
            reader: "JSONReader",
            errorHandler: errorHandler,
            log: log,
            decode: { try decoder.decode(Value.self, from: $0) },
            handler: handler
        )
    }
}
