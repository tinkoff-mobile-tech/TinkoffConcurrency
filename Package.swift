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
    ),
    .library(
      name: "TinkoffConcurrencyTesting",
      targets: ["TinkoffConcurrencyTesting"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "TinkoffConcurrency",
      path: "Development/TinkoffConcurrency"
    ),
    .target(
      name: "TinkoffConcurrencyTesting",
      dependencies: ["TinkoffConcurrency"],
      path: "Development/TinkoffConcurrencyTesting"
    ),
    .testTarget(
      name: "TinkoffConcurrency_Tests",
      dependencies: ["TinkoffConcurrency", "TinkoffConcurrencyTesting"],
      path: "Tests"
    )
  ]
)
