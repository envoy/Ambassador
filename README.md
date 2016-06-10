# Ambassador

[![Build Status](https://travis-ci.org/envoy/Ambassador.svg?branch=master)](https://travis-ci.org/envoy/Ambassador)
[![Code Climate](https://codeclimate.com/repos/575b39108524ed0091001237/badges/4c5ceffe02f98eb2159d/gpa.svg)](https://codeclimate.com/repos/575b39108524ed0091001237/feed)
[![Issue Count](https://codeclimate.com/repos/575b39108524ed0091001237/badges/4c5ceffe02f98eb2159d/issue_count.svg)](https://codeclimate.com/repos/575b39108524ed0091001237/feed)
[![GitHub license](https://img.shields.io/github/license/envoy/Ambassador.svg)](https://github.com/envoy/Ambassador/blob/master/LICENSE)

Lightweight web framework in Swift based on SWSGI for iOS UI Automatic testing data mocking

## Features

 - Super lightweight
 - Easy to use, designed for UI automatic testing API mocking
 - Based on [SWSGI](https://github.com/envoy/Embassy#whats-swsgi-swift-web-server-gateway-interface), can run with HTTP server other than [Embassy](https://github.com/envoy/Embassy)
 - Async friendly

## Example

Here's an example how to mock API endpoints with Ambassador and [Embassy](https://github.com/envoy/Embassy) as the HTTP server.

```Swift
import Embassy
import Ambassador

let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
let router = Router()
let server = HTTPServer(eventLoop: loop, app: router.app, port: 8080)

router["/api/v2/users"] = DelayResponse(JSONResponse(handler: { _ -> AnyObject in
    return [
        ["id": "01", "name": "john"],
        ["id": "02", "name": "tom"]
    ]
}))

// Start HTTP server to listen on the port
try! server.start()

// Run event loop
loop.runForever()
```

Then you can visit [http://[::1]:8080/api/v2/users](http://[::1]:8080/api/v2/users) in the browser, or use HTTP client to GET the URL and see

```
[
  {
    "id" : "01",
    "name" : "john"
  },
  {
    "id" : "02",
    "name" : "tom"
  }
]
```

## Router

`Router` allows you to map different path to different `WebApp`. Like what you saw in the previous example, to route path `/api/v2/users` to our response handler, you simply set the desired path with the `WebApp` as the value

```Swift
let router = Router()
router["/api/v2/users"] = DelayResponse(JSONResponse(handler: { _ -> AnyObject in
    return [
        ["id": "01", "name": "john"],
        ["id": "02", "name": "tom"]
    ]
}))
```

and pass `router.app` as the SWSGI interface to the HTTP server. When the visit path is not found, `router.notFoundResponse` will be used, it simply returns 404. You can overwrite the `notFoundResponse` to customize the not found behavior.

## DataResponse

`DataResponse` is a helper for sending back data. For example, say if you want to make an endpoint to return status code 500, you can do

```Swift
router["/api/v2/return-error"] = DataResponse(statusCode: 500, statusMessage: "server error")
```

Status is `200 OK`, and content type is `application/octet-stream` by default, they all can be overwritten via init parameters. You can also provide custom headers and a handler for returning the data. For example:

```Swift
router["/api/v2/xml"] = DataResponse(
    statusCode: 201,
    statusMessage: "created",
    contentType: "application/xml",
    headers: [("X-Foo-Bar", "My header")]
) { environ -> [UInt8] in
    return Array("<xml>who uses xml nowadays?</xml>".utf8)
}
```

If you prefer to send body back in async manner, you can also use another init that comes with extra `sendData` function as parameter

```Swift
router["/api/v2/xml"] = DataResponse(
    statusCode: 201,
    statusMessage: "created",
    contentType: "application/xml",
    headers: [("X-Foo-Bar", "My header")]
) { (environ, sendData) in
    sendData(Array("<xml>who uses xml nowadays?</xml>".utf8))
}
```

Please notice, unlike `sendBody` for SWSGI, `sendData` only expects to be called once with the whole chunk of data.
