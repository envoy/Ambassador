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

    /// Characters that may appear literally in a URL query component. `CharacterSet
    /// .urlQueryAllowed` already excludes `%` and `#` on Apple platforms today, so this
    /// subtraction is belt-and-braces against a future/foreign definition that doesn't.
    /// What it buys in practice: a *stray* `%` (one that isn't part of a valid escape,
    /// handled separately by the loop's first branch below) falls through to the encode
    /// branch and becomes `%25`, rather than being treated as a literal query character.
    private static let queryAllowed = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "%#"))

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
        guard let components = URLComponents(string: "?" + normalized(string)),
            let items = components.percentEncodedQueryItems else {
            return []
        }
        return items.map { item in
            let value = item.value ?? ""
            return (
                item.name.removingPercentEncoding ?? item.name,
                value.removingPercentEncoding ?? value
            )
        }
    }

    /// Rewrite a raw request body into a strictly valid URL query component, preserving any
    /// percent escapes it already contains.
    ///
    /// This pre-pass is what makes `URLComponents` usable here. Given a query containing any
    /// character that is illegal in a query component — an unencoded space, say — Foundation
    /// falls back to treating the entire query as literal text and stops percent-decoding
    /// every parameter in the body, not just the offending one.
    ///
    /// Existing escape sequences are copied through byte-identically rather than decoded and
    /// re-encoded, so the result is idempotent: normalizing an already-normalized string
    /// returns it unchanged.
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
                // escape), so encode it and let URLComponents decode it back. `.alphanumerics`
                // is the *Unicode* alphanumeric set (`é`, `中`, etc. are members), which would
                // seem to let non-ASCII letters through unencoded here — but
                // `addingPercentEncoding` always encodes non-ASCII regardless of the allowed
                // set, so every scalar reaching this branch comes out percent-escaped.
                let escaped = String(scalar)
                    .addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
                result.append(contentsOf: escaped.unicodeScalars)
                index += 1
            }
        }
        return String(result)
    }

    /// Deliberately ASCII-only, unlike `Character.isHexDigit` — which returns true for
    /// fullwidth digits/letters like `０`/`ｆ`. Using that would make `%０0` look like a
    /// valid escape sequence, pass it through untouched, and hand URLComponents a
    /// malformed query.
    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
            || ("a"..."f").contains(scalar)
            || ("A"..."F").contains(scalar)
    }
}
