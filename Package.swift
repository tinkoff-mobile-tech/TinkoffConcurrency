// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "tinkoff-concurrency",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6)
  ],
  products: [
    .library(
      name: "TinkoffConcurrency",
      targets: ["TinkoffConcurrency"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "TinkoffConcurrency",
      path: "Development/Source"
    ),
    .testTarget(
      name: "TinkoffConcurrency_Tests",
      dependencies: ["TinkoffConcurrency"],
      path: "Tests"
    )
  ]
)
