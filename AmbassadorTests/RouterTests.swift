//
//  RouterTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class RouterTests: XCTestCase {
    func testRouter() {
        let router = Router()
        router["/path/to/1"] = DataResponse() { environ -> Data in
            return Data("hello".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/path/to/1",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "hello")
        XCTAssertEqual(receivedData.last?.count, 0)
    }

    func testRegularExpressionRouting() {
        let router = Router()
        var receivedCaptures: [String]?
        let emailRoute = "/activate/email/([a-zA-Z0-9]+@[a-zA-Z0-9]+\\.[a-zA-Z0-9]+)" +
            "/code/([a-zA-Z0-9]+)"
        router[emailRoute] = DataResponse() { environ -> Data in
            receivedCaptures = environ["ambassador.router_captures"] as? [String]
            return Data("email".utf8)
        }
        router["/foo"] = DataResponse() { environ -> Data in
            return Data("foo".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/egg",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/activate/email/fang@envoy.com/code/ABCD1234",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "email")
        XCTAssertEqual(receivedData.last?.count, 0)
        XCTAssertEqual(receivedCaptures ?? [], ["fang@envoy.com", "ABCD1234"])
    }

    func testRoutingOnSimilarRoutes() {
        let router = Router()
        router["/resource"] = DataResponse() { environ -> Data in
            return Data("index".utf8)
        }
        router["/resource/([0-9])"] = DataResponse() { environ -> Data in
            return Data("show".utf8)
        }
        router["/resource/([a-zA-Z0-9-]+)"] = DataResponse() { environ -> Data in
            return Data("show uuid".utf8)
        }
        router["/resource/([0-9])/action"] = DataResponse() { environ -> Data in
            return Data("action on single resource".utf8)
        }
        router["/resource/([a-zA-Z0-9-]+)/action"] = DataResponse() { environ -> Data in
            return Data("action on single resource with uuid".utf8)
        }
        router["/resource/types"] = DataResponse() { environ -> Data in
            return Data("static".utf8)
        }
        router["/resource/verylongandexplicitstaticmethod"] = DataResponse() { environ -> Data in
            return Data("verylongandexplicitstaticmethod".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }

        // test /resource
        var environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "index")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()


        // test /resource/([0-9])
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/1",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "show")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/([a-zA-Z0-9-]+)
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/\(UUID().uuidString)",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "show uuid")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/([0-9])/action
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/1/action",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "action on single resource")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/types
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/types",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "static")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/verylongandexplicitstaticmethod
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/verylongandexplicitstaticmethod",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "verylongandexplicitstaticmethod")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()
    }
}
