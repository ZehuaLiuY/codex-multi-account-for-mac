// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexAccounts",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexAccounts", targets: ["CodexAccounts"])],
    targets: [
        .executableTarget(name: "CodexAccounts", resources: [.process("Resources")]),
        .testTarget(name: "CodexAccountsTests", dependencies: ["CodexAccounts"])
    ]
)
