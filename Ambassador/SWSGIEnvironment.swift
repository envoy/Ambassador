//
//  SWSGIEnvironment.swift
//  Ambassador
//

import Foundation

import Embassy

/// Typed read access to a SWSGI `environ` dictionary. Get one with `environ.swsgi`.
public struct SWSGIEnvironment {
    static let routerCapturesKey = "ambassador.router_captures"

    /// The underlying environ dictionary
    public let environ: [String: Any]

    public init(_ environ: [String: Any]) {
        self.environ = environ
    }

    /// The request body stream. Traps if the environ has no `swsgi.input`, as every environ from
    /// Embassy's server does.
    public var input: SWSGIInput {
        environ["swsgi.input"] as! SWSGIInput
    }

    /// HTTP method, e.g. `GET`
    public var requestMethod: String? {
        environ["REQUEST_METHOD"] as? String
    }

    /// Request path, without the query string
    public var pathInfo: String? {
        environ["PATH_INFO"] as? String
    }

    /// Query string, without the leading `?`
    public var queryString: String? {
        environ["QUERY_STRING"] as? String
    }

    /// The query string parsed as URL parameters; empty when there is no query string
    public var queryParameters: FormParameters {
        guard let queryString, !queryString.isEmpty else { return FormParameters([]) }
        return FormParameters(parsing: queryString)
    }

    /// Value of the `Content-Type` request header
    public var contentType: String? {
        environ["CONTENT_TYPE"] as? String
    }

    /// Capture groups from the `Router` pattern that matched this request; empty when there are none
    public var routerCaptures: [String] {
        environ[SWSGIEnvironment.routerCapturesKey] as? [String] ?? []
    }

    /// The event loop serving this request. Internal so Embassy's `EventLoop` stays out of the
    /// public API.
    var eventLoop: EventLoop? {
        environ["embassy.event_loop"] as? EventLoop
    }

    /// Value of the request header `name`, matched case-insensitively (e.g. `"Authorization"`
    /// reads `HTTP_AUTHORIZATION`)
    public func header(_ name: String) -> String? {
        let key = "HTTP_" + name.uppercased().replacingOccurrences(of: "-", with: "_")
        return environ[key] as? String
    }
}

extension Dictionary where Key == String, Value == Any {
    /// Typed accessors for this SWSGI environ
    public var swsgi: SWSGIEnvironment {
        SWSGIEnvironment(self)
    }
}
