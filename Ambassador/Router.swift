//
//  Router.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Router WebApp for routing requests to different WebApp
open class Router: WebApp {
    var routes: [String: WebApp] = [:]
    open var notFoundResponse: WebApp = DataResponse(
        statusCode: 404,
        statusMessage: "Not found"
    )
    private let semaphore = DispatchSemaphore(value: 1)

    public init() {
    }

    open subscript(path: String) -> WebApp? {
        get {
            // enter critical section
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            defer {
                semaphore.signal()
            }
            return routes[path]
        }

        set {
            // enter critical section
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            defer {
                semaphore.signal()
            }
            routes[path] = newValue!
        }
    }

    open func app(
        _ environ: [String: Any],
        startResponse: @escaping ((String, [(String, String)]) -> Void),
        sendBody: @escaping ((Data) -> Void)
    ) {
        let path = environ["PATH_INFO"] as! String

        if let (webApp, captures) = matchRoute(to: path) {
            var environ = environ
            environ["ambassador.router_captures"] = captures
            webApp.app(environ, startResponse: startResponse, sendBody: sendBody)
            return
        }
        return notFoundResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }

    private func matchRoute(to searchPath: String) -> (WebApp, [String])? {
        typealias ReturnValue = (WebApp, [String])
        var routeMatches: [(NSTextCheckingResult, ReturnValue)] = []
        for (path, route) in routes {
            let regex = try! NSRegularExpression(pattern: path, options: [])
            let matches = regex.matches(
                in: searchPath,
                options: [],
                range: NSRange(location: 0, length: searchPath.count)
            )
            if !matches.isEmpty {
                let match = matches[0]
                guard match.range.length == searchPath.count else { continue }
                let searchPath = NSString(string: searchPath)
                var captures = [String]()
                for rangeIdx in 1 ..< match.numberOfRanges {
                    captures.append(searchPath.substring(with: match.range(at: rangeIdx)))
                }
                let possibleReturnValue = (route, captures)
                routeMatches.append((match, possibleReturnValue))
            }
        }
        
        // sort the most specific route to top and return the result
        return routeMatches.sorted(by: { (routeMatch1, routeMatch2) -> Bool in
            guard let regex1 = routeMatch1.0.regularExpression,
                let regex2 = routeMatch2.0.regularExpression
            else {
                return false
            }

            // prefer regex without capture groups
            // skip this decision when number of capture groups are equal
            if regex1.numberOfCaptureGroups < regex2.numberOfCaptureGroups {
                return true
            } else if regex1.numberOfCaptureGroups > regex2.numberOfCaptureGroups {
                return false
            }

            // prefer the shorter regex pattern
            return regex1.pattern.count < regex2.pattern.count
        }).first?.1
    }
}
