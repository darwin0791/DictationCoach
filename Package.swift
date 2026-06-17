// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AIEnglishDictationCoach",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DictationCoach", targets: ["DictationCoachApp"])
    ],
    targets: [
        .executableTarget(
            name: "DictationCoachApp",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
