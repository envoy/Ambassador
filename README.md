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
