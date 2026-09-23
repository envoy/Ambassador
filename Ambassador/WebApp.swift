//
//  WebApp.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

import Embassy

/// Web Application
public protocol WebApp {
    func app(
        _ environ: [String: Any],
        startResponse: @escaping SWSGIStartResponse,
        sendBody: @escaping SWSGISendBody
    )
}
