// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MealPlanner",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MealPlanner",
            targets: ["MealPlanner"]),
    ],
    targets: [
        .executableTarget(
            name: "MealPlanner",
            path: "MealPlanner"),
        .testTarget(
            name: "MealPlannerTests",
            dependencies: ["MealPlanner"],
            path: "MealPlannerTests"),
    ]
)
