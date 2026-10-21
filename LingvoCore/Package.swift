// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LingvoCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LingvoCore", targets: ["LingvoCore"]),
        .executable(name: "lingvo-dict", targets: ["lingvo-dict"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
    ],
    targets: [
        .target(
            name: "LingvoCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "lingvo-dict",
            dependencies: ["LingvoCore"]
        ),
        .testTarget(
            name: "LingvoCoreTests",
            dependencies: ["LingvoCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
