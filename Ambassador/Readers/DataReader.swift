//
//  DataReader.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public enum DataReader {
    /// Read all data into bytes array and pass it to handler
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter handler: the handler to be called when finish reading all data
    public static func read(_ input: SWSGIInput, handler: @escaping ((Data) -> Void)) {
        var buffer: Data = Data()
        // read all data into buffer
        input { data in
            buffer.append(data)
            // EOF, flush
            if data.isEmpty {
                handler(buffer)
            }
        }
    }

    /// Read the request body from `environ["swsgi.input"]` and pass it to handler
    ///  - Parameter environ: the SWSGI environ of the request
    ///  - Parameter handler: the handler to be called when finish reading all data
    public static func read(_ environ: [String: Any], handler: @escaping ((Data) -> Void)) {
        read(environ.swsgi.input, handler: handler)
    }

    // swiftlint:disable function_parameter_count
    /// Read the whole body, then decode it. On success `handler` gets the value; on failure
    /// `errorHandler` gets the error, or, when it's `nil`, the failure is logged via `log`.
    ///  - Parameter reader: the reader's name, used in the log message
    static func decode<Value>(
        _ input: SWSGIInput,
        reader: String,
        errorHandler: ((Error) -> Void)?,
        log: @escaping (String) -> Void,
        decode: @escaping (Data) throws -> Value,
        handler: @escaping (Value) -> Void
    ) {
        read(input) { data in
            let value: Value
            do {
                value = try decode(data)
            } catch {
                if let errorHandler {
                    errorHandler(error)
                } else {
                    logReadFailure(reader: reader, byteCount: data.count, error: error, log: log)
                }
                return
            }
            handler(value)
        }
    }
    // swiftlint:enable function_parameter_count

    /// Report a body that a reader couldn't decode when the caller passed no `errorHandler`.
    /// The caller's handler isn't called, so no response is sent and the request hangs until the
    /// client times out; this message is the only trace of why.
    static func logReadFailure(
        reader: String,
        byteCount: Int,
        error: Error,
        log: (String) -> Void = logToStandardError
    ) {
        log(
            "Ambassador: \(reader) failed to parse request body (\(byteCount) bytes): \(error). " +
            "Handler not called; no response will be sent."
        )
    }

    static func logToStandardError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
