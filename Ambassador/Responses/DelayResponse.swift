//
//  DelayResponse.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

/// A response app makes another app to delay its response for a specific time period
public struct DelayResponse: WebApp {
    public enum Delay {
        case random(min: TimeInterval, max: TimeInterval)
        case delay(seconds: TimeInterval)
        case never
        case none
    }

    public let delay: Delay
    public let delayedApp: WebApp

    public init(_ app: WebApp, delay: Delay = .random(min: 0.1, max: 3)) {
        delayedApp = app
        self.delay = delay
    }

    public func app(
        _ environ: [String: Any],
        startResponse: @escaping SWSGIStartResponse,
        sendBody: @escaping SWSGISendBody
    ) {
        let delayTime: TimeInterval
        switch delay {
        case .none:
            delayedApp.app(environ, startResponse: startResponse, sendBody: sendBody)
            return
        case .never:
            return
        case .delay(let seconds):
            delayTime = seconds
        case .random(let min, let max):
            delayTime = TimeInterval.random(in: min ... max)
        }
        let loop = environ.swsgi.eventLoop!

        let delayedStartResponse: SWSGIStartResponse = { status, headers in
            loop.call(withDelay: delayTime) {
                startResponse(status, headers)
            }
        }
        let delayedSendBody: SWSGISendBody = { data in
            loop.call(withDelay: delayTime) {
                sendBody(data)
            }
        }
        delayedApp.app(environ, startResponse: delayedStartResponse, sendBody: delayedSendBody)
    }
}

extension WebApp {
    /// Wrap this app in a `DelayResponse`, e.g. `JSONResponse(...).delayed(.delay(seconds: 0.05))`.
    /// The default delay matches `DelayResponse.init`.
    public func delayed(_ delay: DelayResponse.Delay = .random(min: 0.1, max: 3)) -> DelayResponse {
        DelayResponse(self, delay: delay)
    }
}
