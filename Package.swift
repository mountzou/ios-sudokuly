// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SudokulyCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "SudokulyCore", targets: ["SudokulyCore"])],
    targets: [
        .target(name: "SudokulyCore", path: "Sudokuly/Core"),
        .testTarget(name: "SudokulyCoreTests", dependencies: ["SudokulyCore"], path: "Tests/SudokulyTests")
    ]
)
