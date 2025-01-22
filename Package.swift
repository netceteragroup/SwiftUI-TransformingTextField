// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TransformingTextField",
    platforms: [.iOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TransformingTextField",
            targets: ["TransformingTextField"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/siteline/swiftui-introspect", from: "1.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TransformingTextField",
            dependencies: [
                .product(name: "SwiftUIIntrospect", package: "swiftui-introspect")
            ]
        ),
        .testTarget(
            name: "TransformingTextFieldTests",
            dependencies: ["TransformingTextField"]
        )
    ]
)
