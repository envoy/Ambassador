//
//  WebApp.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/30/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

/// WebApp is a WebAppType for building web app with any SWSGI handler
public struct WebApp: WebAppType {
    private let handler: SWSGI
    public init(handler: SWSGI) {
        self.handler = handler
    }

    public func app(
        environ: [String: Any],
        startResponse: ((String, [(String, String)]) -> Void),
        sendBody: ([UInt8] -> Void)
    ) {
        handler(environ: environ, startResponse: startResponse, sendBody: sendBody)
    }
}
