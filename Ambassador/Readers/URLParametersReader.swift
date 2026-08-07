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
    public enum LocalError: Error {
        case utf8EncodingError
    }

    /// Characters that may appear literally in a URL query component. `%` is excluded so
    /// existing escape sequences can be passed through explicitly rather than re-encoded,
    /// and `#` so that it can't be mistaken for the start of a fragment.
    private static let queryAllowed = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "%#"))

    /// Read all data into bytes array and parse it as URL parameter
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter errorHandler: the handler to be called when failed to read URL parameters
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as URL
    ///                       parameter
    public static func read(
        _ input: SWSGIInput,
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping (([(String, String)]) -> Void)
    ) {
        DataReader.read(input) { data in
            do {
                guard let string = String(bytes: data, encoding: .utf8) else {
                    throw LocalError.utf8EncodingError
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
    public static func parseURLParameters(_ string: String) -> [(String, String)] {
        guard let components = URLComponents(string: "?" + normalized(string)),
            let items = components.queryItems else {
            return []
        }
        return items.map { ($0.name, $0.value ?? "") }
    }

    /// Rewrite a raw request body into a strictly valid URL query component, preserving any
    /// percent escapes it already contains.
    ///
    /// This pre-pass is what makes `URLComponents` usable here. Given a query containing any
    /// character that is illegal in a query component — an unencoded space, say — Foundation
    /// falls back to treating the entire query as literal text and stops percent-decoding
    /// every parameter in the body, not just the offending one.
    private static func normalized(_ string: String) -> String {
        let scalars = Array(string.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "%",
                index + 2 < scalars.count,
                isHexDigit(scalars[index + 1]),
                isHexDigit(scalars[index + 2]) {
                // Already a valid escape sequence — pass it through untouched.
                result.append(contentsOf: scalars[index...(index + 2)])
                index += 3
            } else if queryAllowed.contains(scalar) {
                result.append(scalar)
                index += 1
            } else {
                // Illegal in a query component (including a `%` that doesn't begin a valid
                // escape), so encode it and let URLComponents decode it back.
                let escaped = String(scalar)
                    .addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
                result.append(contentsOf: escaped.unicodeScalars)
                index += 1
            }
        }
        return String(result)
    }

    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
            || ("a"..."f").contains(scalar)
            || ("A"..."F").contains(scalar)
    }
}
