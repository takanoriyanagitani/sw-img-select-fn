// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ImageSelectFn",
  platforms: [
    .macOS(.v11)
  ],
  products: [
    .library(
      name: "ImageSelectFn",
      targets: ["ImageSelectFn"])
  ],
  dependencies: [
    .package(url: "https://github.com/realm/SwiftLint", from: "0.58.2"),
    .package(
      url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"
    ),
  ],
  targets: [
    .target(
      name: "ImageSelectFn"),
    .testTarget(
      name: "ImageSelectFnTests",
      dependencies: ["ImageSelectFn"]
    ),
  ]
)
