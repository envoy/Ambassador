//
//  URLParametersReader.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

public struct URLParametersReader {
    public enum Error: ErrorType {
        case UTF8EncodingError
    }

    /// Read all data into bytes array and parse it as URL parameter
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter errorHandler: the handler to be called when failed to read URL parameters
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as URL
    ///                       parameter
    public static func read(
        input: SWSGIInput,
        errorHandler: (ErrorType -> Void)? = nil,
        handler: ([(String, String)] -> Void)
        ) {
        DataReader.read(input) { data in
            do {
                guard let string = String(bytes: data, encoding: NSUTF8StringEncoding) else {
                    throw Error.UTF8EncodingError
                }
                let parameters = URLParametersReader.parseURLParameters(string)
                handler(parameters)
            } catch {
                if let errorHandler = errorHandler {
                    errorHandler(error)
                }
            }
        }
    }

    /// Parse given string as URL parameters
    ///  - Parameter string: URL encoded parameter string to parse
    ///  - Returns: array of (key, value) pairs of URL encoded parameters
    public static func parseURLParameters(string: String) -> [(String, String)] {
        let parameters = string.componentsSeparatedByString("&")
        return parameters.map { parameter in
            let parts = parameter.componentsSeparatedByString("=")
            let key = parts[0]
            let value = Array(parts[1..<parts.count]).joinWithSeparator("=")
            return (
                key.stringByRemovingPercentEncoding ?? key,
                value.stringByRemovingPercentEncoding ?? value
            )
        }
    }
}
