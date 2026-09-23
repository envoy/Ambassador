//
//  DataReader.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

public struct DataReader {
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
