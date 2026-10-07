// swift-tools-version: 6.0
import PackageDescription

// The household core: every domain rule in GLOSSARY.md, in plain Swift.
// No SwiftUI, CloudKit or UserNotifications in here; the app depends on this
// package, never the other way round.
let package = Package(
    name: "HouseholdCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "HouseholdCore", targets: ["HouseholdCore"]),
    ],
    targets: [
        .target(name: "HouseholdCore"),
        .testTarget(name: "HouseholdCoreTests", dependencies: ["HouseholdCore"]),
    ]
)
