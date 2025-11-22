// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Seven365Zyprinter",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "Seven365Zyprinter",
            targets: ["Seven365ZyprinterPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "Seven365ZyprinterPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources",
            exclude: [
                "sources/GCD/Documentation.html"
            ],
            sources: [
                "Plugin/ZyprintPlugin.swift",
                "Plugin/ZywellSDK.swift",
                "sources"
            ],
            publicHeadersPath: "Plugin",
            cSettings: [
                .headerSearchPath("sources"),
                .headerSearchPath("sources/GCD"),
                .headerSearchPath("Plugin")
            ]
        ),
        .testTarget(
            name: "Seven365ZyprinterPluginTests",
            dependencies: ["Seven365ZyprinterPlugin"],
            path: "ios/Tests/ExamplePluginTests")
    ]
)