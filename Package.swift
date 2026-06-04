// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TouchTouch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TouchTouch", targets: ["TouchTouch"])
    ],
    targets: [
        .executableTarget(
            name: "TouchTouch",
            path: "Sources/TouchTouch"
        ),
        .testTarget(
            name: "TouchTouchTests",
            dependencies: ["TouchTouch"],
            path: "Tests/TouchTouchTests"
        )
    ]
)
