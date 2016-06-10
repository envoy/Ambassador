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
struct DelayResponse: WebAppType {
    enum Delay {
        case Random(min: NSTimeInterval, max: NSTimeInterval)
        case Delay(seconds: NSTimeInterval)
        case Never
        case None
    }

    var delay: Delay
    let delayedApp: WebAppType

    init(_ app: WebAppType, delay: Delay = .Random(min: 0.1, max: 3)) {
        delayedApp = app
        self.delay = delay
    }

    func app(
        environ: [String: Any],
        startResponse: ((String, [(String, String)]) -> Void),
        sendBody: ([UInt8] -> Void)
    ) {
        var delayTime: NSTimeInterval!
        switch delay {
        case .None:
            delayedApp.app(environ, startResponse: startResponse, sendBody: sendBody)
            return
        case .Never:
            return
        case .Delay(let seconds):
            delayTime = seconds
        case .Random(let min, let max):
            let random = (Double(arc4random()) / 0x100000000)
            delayTime = min + (max - min) * random
        }
        let loop = environ["embassy.event_loop"] as! EventLoopType

        let delayedStartResponse = { (status: String, headers: [(String, String)]) in
            loop.callLater(delayTime) {
                startResponse(status, headers)
            }
        }
        let delayedSendBody = { (data: [UInt8]) in
            loop.callLater(delayTime) {
                sendBody(data)
            }
        }
        delayedApp.app(environ, startResponse: delayedStartResponse, sendBody: delayedSendBody)
    }
}
