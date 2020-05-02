// swift-tools-version:5.2
import PackageDescription

let package = Package(
  name: "OutlineViewDiffableDataSource",
  platforms: [.macOS(.v10_15)],
  products: [.library(name: "OutlineViewDiffableDataSource", targets: ["OutlineViewDiffableDataSource"])],
  targets: [
    .target(name: "OutlineViewDiffableDataSource", dependencies: [], path: "Sources"),
    .testTarget(name: "OutlineViewDiffableDataSourceTests", dependencies: ["OutlineViewDiffableDataSource"], path: "Tests"),
  ]
)
