// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "tinkoff-concurrency",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "TinkoffConcurrency",
      targets: ["TinkoffConcurrency"]
    )
  ],
  targets: [
    .target(
      name: "TinkoffConcurrency",
      path: "Development/Source"
    ),
    .testTarget(
      name: "TinkoffConcurrency_Tests",
      dependencies: ["TinkoffConcurrency"],
      path: "Example/Tests"
    ),
  ]
)
