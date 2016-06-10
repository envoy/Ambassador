//
//  Router.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Router WebApp for routing requests to different WebApp
public class Router: WebAppType {
    var routes: [String: WebAppType] = [:]
    public var notFoundResponse: WebAppType = DataResponse(
        statusCode: 404,
        statusMessage: "Not found"
    )
    private let semaphore = dispatch_semaphore_create(1)

    public init() {
    }

    public subscript(path: String) -> WebAppType? {
        get {
            // enter critical section
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            defer {
                dispatch_semaphore_signal(semaphore)
            }
            return routes[path]
        }

        set {
            // enter critical section
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            defer {
                dispatch_semaphore_signal(semaphore)
            }
            routes[path] = newValue!
        }
    }

    public func app(
        environ: [String: Any],
        startResponse: ((String, [(String, String)]) -> Void),
        sendBody: ([UInt8] -> Void)
    ) {
        let path = environ["PATH_INFO"] as! String
        // TODO: in the future, this should also support pattern matching
        if let webApp = routes[path] {
            webApp.app(environ, startResponse: startResponse, sendBody: sendBody)
            return
        }
        return notFoundResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }
}
