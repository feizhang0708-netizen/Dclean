// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dclean",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Dclean",
            path: "Sources/Dclean",
            resources: [.process("Resources")],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("ServiceManagement")
            ]
        ),
    ]
)
