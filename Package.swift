// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ztp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ztp", targets: ["ZTPCLI"]),
        .library(name: "ZTPCore", targets: ["ZTPCore"]),
        .library(name: "ZTPProtocols", targets: ["ZTPProtocols"]),
        .library(name: "ZTPExcel", targets: ["ZTPExcel"]),
        .library(name: "ZTPDocx", targets: ["ZTPDocx"]),
        .library(name: "ZTPSlides", targets: ["ZTPSlides"]),
        .library(name: "ZTPChart", targets: ["ZTPChart"]),
        .library(name: "ZTPMail", targets: ["ZTPMail"]),
        .library(name: "ZTPMessage", targets: ["ZTPMessage"]),
        .library(name: "ZTPBrowser", targets: ["ZTPBrowser"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "ZTPCLI",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
                "ZTPExcel",
                "ZTPDocx",
                "ZTPSlides",
                "ZTPChart",
                "ZTPMail",
                "ZTPMessage",
                "ZTPBrowser",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "ZTPBrowser",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPMessage",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPMail",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPChart",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPSlides",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPDocx",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPExcel",
            dependencies: [
                "ZTPCore",
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPCore",
            dependencies: [
                "ZTPProtocols",
            ]
        ),
        .target(
            name: "ZTPProtocols"
        ),
        .testTarget(
            name: "ZTPBrowserTests",
            dependencies: ["ZTPBrowser"]
        ),
        .testTarget(
            name: "ZTPMessageTests",
            dependencies: ["ZTPMessage"]
        ),
        .testTarget(
            name: "ZTPMailTests",
            dependencies: ["ZTPMail"]
        ),
        .testTarget(
            name: "ZTPChartTests",
            dependencies: ["ZTPChart"]
        ),
        .testTarget(
            name: "ZTPSlidesTests",
            dependencies: ["ZTPSlides"]
        ),
        .testTarget(
            name: "ZTPDocxTests",
            dependencies: ["ZTPDocx"]
        ),
        .testTarget(
            name: "ZTPExcelTests",
            dependencies: ["ZTPExcel"]
        ),
        .testTarget(
            name: "ZTPCLITests",
            dependencies: ["ZTPCLI"]
        ),
        .testTarget(
            name: "ZTPCoreTests",
            dependencies: ["ZTPCore"]
        ),
        .testTarget(
            name: "ZTPProtocolsTests",
            dependencies: ["ZTPProtocols"]
        ),
    ]
)
