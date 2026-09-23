//
//  SWSGI.swift
//  Ambassador
//

import Foundation

// Ambassador's public API is written in these SWSGI types, so they're declared here: consumers can
// name them with only `import Ambassador`. Each is the same function type Embassy declares, so the
// two are interchangeable and code importing both modules still compiles. (They can't be written as
// `Embassy.SWSGI`: Embassy's `enum Embassy` shadows the module name.)

/// A SWSGI app as a bare closure: `(environ, startResponse, sendBody)`
public typealias SWSGI = (
    [String: Any],
    @escaping SWSGIStartResponse,
    @escaping SWSGISendBody
) -> Void

/// Starts the response with a status line (e.g. `"200 OK"`) and headers
public typealias SWSGIStartResponse = @Sendable (String, [(String, String)]) -> Void

/// Sends a chunk of the response body; an empty `Data` ends the body
public typealias SWSGISendBody = @Sendable (Data) -> Void

/// The request body stream: pass a handler to receive chunks, ending with an empty `Data`
public typealias SWSGIInput = (((Data) -> Void)?) -> Void
