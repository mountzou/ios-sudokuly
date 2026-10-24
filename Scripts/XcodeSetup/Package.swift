// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SudokulyXcodeSetup",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.27.7"))],
    targets: [.executableTarget(name: "SudokulyXcodeSetup", dependencies: ["XcodeProj"], path: "Sources")]
)
