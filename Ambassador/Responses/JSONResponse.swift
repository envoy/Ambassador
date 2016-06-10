//
//  JSONResponse.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

/// A response app for responding JSON data
struct JSONResponse: WebAppType {
    /// Underlying data response
    var dataResponse: DataResponse

    init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: NSJSONWritingOptions = .PrettyPrinted,
        headers: [(String, String)] = [],
        handler: (environ: [String: Any], sendJSON: AnyObject -> Void) -> Void
        ) {
        dataResponse = DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            handler(environ: environ) { json in
                let data = try! NSJSONSerialization.dataWithJSONObject(json, options: jsonWritingOptions)
                let bytes = Array(UnsafeBufferPointer(
                    start: UnsafePointer<UInt8>(data.bytes),
                    count: data.length
                    ))
                sendData(bytes)
            }
        }
    }

    init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: NSJSONWritingOptions = .PrettyPrinted,
        headers: [(String, String)] = [],
        handler: ((environ: [String: Any]) -> AnyObject)? = nil
        ) {
        dataResponse = DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            let data: NSData
            if let handler = handler {
                let json = handler(environ: environ)
                data = try! NSJSONSerialization.dataWithJSONObject(json, options: jsonWritingOptions)
            } else {
                data = NSData()
            }
            let bytes = Array(UnsafeBufferPointer(
                start: UnsafePointer<UInt8>(data.bytes),
                count: data.length
                ))
            sendData(bytes)
        }
    }
    
    func app(
        environ: [String: Any],
        startResponse: ((String, [(String, String)]) -> Void),
        sendBody: ([UInt8] -> Void)
        ) {
        return dataResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }
}
