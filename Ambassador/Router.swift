//
//  Router.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

/// Router WebApp for routing requests to different WebApp
open class Router: WebApp {
    private struct Route {
        let regex: NSRegularExpression
        let app: WebApp
    }

    private var routes: [String: Route] = [:]
    open var notFoundResponse: WebApp = DataResponse(
        statusCode: 404,
        statusMessage: "Not found"
    )
    // Routes are typically registered from a test thread while the event loop reads them
    private let lock = NSLock()

    public init() {
    }

    /// The WebApp for requests whose `PATH_INFO` matches the regular expression `path`.
    /// Matching is not anchored; use `^` and `$` to match the whole path. Assigning `nil` removes
    /// the route.
    open subscript(path: String) -> WebApp? {
        get {
            locked { routes[path]?.app }
        }

        set {
            // compile outside the lock so an invalid pattern traps here, at the registration site
            let route = newValue.map { Route(regex: try! NSRegularExpression(pattern: path), app: $0) }
            locked { routes[path] = route }
        }
    }

    open func app(
        _ environ: [String: Any],
        startResponse: @escaping SWSGIStartResponse,
        sendBody: @escaping SWSGISendBody
    ) {
        let path = environ["PATH_INFO"] as! String

        if let (webApp, captures) = matchRoute(to: path) {
            var environ = environ
            environ[SWSGIEnvironment.routerCapturesKey] = captures
            webApp.app(environ, startResponse: startResponse, sendBody: sendBody)
            return
        }
        return notFoundResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }

    private func matchRoute(to searchPath: String) -> (WebApp, [String])? {
        let routes = locked { self.routes }
        let searchRange = NSRange(searchPath.startIndex..., in: searchPath)
        for route in routes.values {
            guard let match = route.regex.firstMatch(in: searchPath, range: searchRange) else {
                continue
            }
            // an optional group that didn't participate in the match captures ""
            let captures = (1 ..< match.numberOfRanges).map { index in
                Range(match.range(at: index), in: searchPath).map { String(searchPath[$0]) } ?? ""
            }
            return (route.app, captures)
        }
        return nil
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return body()
    }
}
