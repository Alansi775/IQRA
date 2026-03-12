// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Iqra",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Iqra",
            dependencies: [],
            path: "Iqra",
            resources: [
                .copy(".env")
            ]
        )
    ]
)
