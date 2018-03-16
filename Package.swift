// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "EnvoyAmbassador",
	products: [
		.library(
			name: "Ambassador",
			targets: ["Ambassador"]),
	],
	dependencies: [
		.package(url: "https://github.com/envoy/Embassy.git", from: "4.0.0"),
	],
	targets: [
		.target(
			name: "Ambassador",
			dependencies: ["Embassy"],
			path: "Ambassador"),
		.testTarget(
			name: "AmbassadorTests",
			dependencies: ["Ambassador"],
			path: "AmbassadorTests"),
	]
)
