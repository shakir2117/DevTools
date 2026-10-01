// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevKit",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.7"),
    ],
    targets: [
        .target(
            name: "DevKitCore",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "Markdown", package: "swift-markdown"),
                "SwiftSoup",
            ]
        ),
        .executableTarget(
            name: "DevKit",
            dependencies: ["DevKitCore"],
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
