// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "concurrency-examples",
    dependencies: [
        .package(url: "https://gitlab.sd.apple.com/tkientzle/Future-Swift.git", from: "0.5.3")
    ],
    targets: [
        .target( name: "ConcurrencyExamples", dependencies: ["Future"]),
        .testTarget( name: "ConcurrencyExamplesTests", dependencies: ["ConcurrencyExamples", "Future"]),
    ]
)
