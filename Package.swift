// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ambassador",
    dependencies: [
        .package(url: "https://github.com/envoy/Embassy.git", from: "4.0.5")
    ],
    targets: [
        .target(name: "Ambassador", dependencies: ["Embassy"], path: "Ambassador"),
    ]
)
