// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "combine-schedulers",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_12),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "CombineSchedulers",
      targets: ["CombineSchedulers"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/Incetro/xctest-interface-adapter", .branch("master"))
  ],
  targets: [
    .target(
      name: "CombineSchedulers",
      dependencies: [
        "XCTestInterfaceAdapter"
      ]
    ),
    .testTarget(
      name: "CombineSchedulersTests",
      dependencies: [
        "CombineSchedulers"
      ]
    ),
  ]
)
