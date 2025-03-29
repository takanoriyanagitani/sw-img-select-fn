// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ImgSelStripe",
  platforms: [
    .macOS(.v11)
  ],
  dependencies: [
    .package(path: "../.."),
    .package(url: "https://github.com/realm/SwiftLint", from: "0.58.2"),
  ],
  targets: [
    .executableTarget(
      name: "ImgSelStripe",
      dependencies: [
        .product(name: "ImageSelectFn", package: "sw-img-select-fn")
      ]
    )
  ]
)
