// swift-tools-version:5.4
import PackageDescription

let package = Package(
  name: "OutlineViewDiffableDataSource",
  platforms: [.macOS(.v10_11)],
  products: [.library(name: "OutlineViewDiffableDataSource", targets: ["OutlineViewDiffableDataSource"])],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
  ],
  targets: [
    .target(name: "OutlineViewDiffableDataSource", dependencies: [], path: "Sources"),
    .testTarget(name: "OutlineViewDiffableDataSourceTests", dependencies: ["OutlineViewDiffableDataSource"], path: "Tests"),
  ]
)
