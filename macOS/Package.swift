// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LockInCore", platforms: [.macOS(.v14)], products: [.library(name: "LockInCore", targets: ["LockInCore"])], targets: [.target(name: "LockInCore", path: "Core"), .testTarget(name: "LockInCoreTests", dependencies: ["LockInCore"], path: "Tests/Swift")])
