// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DMCLBMMetalSim",
    // https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "DMCLBMMetal",
            targets: ["DMCLBMMetal"]),
        .executable(
            name: "DMCLBMMetalSim",
            targets: ["DMCLBMMetalSim"]),
    ],
    dependencies: [
        // .package(url: /* package url */, from: "1.0.0"),
        .package(
            url: "https://github.com/mchapman87501/DMCMovieWriter.git",
            from: "1.0.1"),
        .package(
            url: "https://github.com/mchapman87501/DMC2D.git", from: "1.0.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "DMCLBMMetalSim",
            dependencies: ["DMCLBMMetal"]),
        .target(
            name: "DMCLBMMetal",
            dependencies: [
                "DMC2D",
                "DMCMovieWriter",
            ],
            exclude: [
                "Resources/CMakeLists.txt",
                // Xcode will complain if this is missing.
                "Resources/compute.air",
                "Resources/render.air",
            ],
            resources: [
                // Xcode will complain if this is missing.
                .copy("Resources/default.metallib"),
                // `swift build` will copy this.  Xcode will compile it to default.metallib.
                .process("Resources/shared_defs"),
                .process("Resources/compute.metal"),
                .process("Resources/render.metal"),
            ]
            ),
        .testTarget(
            name: "DMCLBMMetalTests",
            dependencies: ["DMCLBMMetal"]),
    ]
)
