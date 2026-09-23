//
//  ResponseRecorder.swift
//  AmbassadorTests
//

import Foundation

import Ambassador

/// Records what a `WebApp` sends through `startResponse`/`sendBody`. The SWSGI callbacks are
/// `@Sendable`, so tests can't capture local `var`s; the tests drive apps synchronously on one
/// thread, which is why `Sendable` is unchecked here.
final class ResponseRecorder: @unchecked Sendable {
    private(set) var statuses: [String] = []
    private(set) var headers: [[(String, String)]] = []
    private(set) var bodies: [Data] = []

    var lastStatus: String? { statuses.last }
    var lastHeaders: [(String, String)] { headers.last ?? [] }

    /// The first value of the header `name` in the last response, compared case-insensitively
    func lastHeader(_ name: String) -> String? {
        lastHeaders.first { $0.0.caseInsensitiveCompare(name) == .orderedSame }?.1
    }

    var startResponse: SWSGIStartResponse {
        { status, headers in
            self.statuses.append(status)
            self.headers.append(headers)
        }
    }

    var sendBody: SWSGISendBody {
        { data in
            self.bodies.append(data)
        }
    }
}
