import Foundation
import XcodeProj
import PathKit

let projectPath = Path(CommandLine.arguments.dropFirst().first ?? "sudokuly.xcodeproj")
let project = try XcodeProj(path: projectPath)
let pbx = project.pbxproj
guard let root = try pbx.rootProject(), let main = root.mainGroup else { fatalError("Missing root project") }
pbx.objectVersion = 77
// Firebase 13 and Google Sign-In 10 require incompatible AppCheck major versions.
// 12.19.2 is the newest stable Firebase release compatible with Google Sign-In 10.
if let firebase = root.remotePackages.first(where: { $0.repositoryURL?.contains("firebase-ios-sdk") == true }) {
    firebase.versionRequirement = .upToNextMajorVersion("12.19.2")
    guard let app = pbx.nativeTargets.first(where: { $0.name == "Sudokuly" }) else { fatalError("Missing app target") }
    // The bundled generic helper chooses nativeTargets.first, whose order isn't stable.
    // Always scope this module to the named application target instead.
    let existing = pbx.nativeTargets.flatMap { $0.packageProductDependencies ?? [] }
        .first(where: { $0.productName == "FirebaseFirestore" })
    let product = existing ?? XCSwiftPackageProductDependency(productName: "FirebaseFirestore", package: firebase)
    if existing == nil { pbx.add(object: product) }
    for target in pbx.nativeTargets where target != app {
        target.packageProductDependencies?.removeAll { $0.productName == "FirebaseFirestore" }
        for phase in target.buildPhases.compactMap({ $0 as? PBXFrameworksBuildPhase }) {
            let files = (phase.files ?? []).filter { $0.product?.productName == "FirebaseFirestore" }
            phase.files?.removeAll { files.contains($0) }
            for file in files { pbx.delete(object: file) }
        }
    }
    if app.packageProductDependencies?.contains(where: { $0.productName == "FirebaseFirestore" }) != true {
        if app.packageProductDependencies == nil { app.packageProductDependencies = [] }
        app.packageProductDependencies?.append(product)
        let phase: PBXFrameworksBuildPhase
        if let existingPhase = app.buildPhases.compactMap({ $0 as? PBXFrameworksBuildPhase }).first { phase = existingPhase }
        else { phase = PBXFrameworksBuildPhase(); pbx.add(object: phase); app.buildPhases.append(phase) }
        let file = PBXBuildFile(product: product)
        pbx.add(object: file)
        if phase.files == nil { phase.files = [] }
        phase.files?.append(file)
    }
}

for (name, folder) in [("Sudokuly", "Sudokuly"), ("SudokulyTests", "Tests/SudokulyTests"), ("SudokulyUITests", "Tests/SudokulyUITests")] {
    guard let target = pbx.nativeTargets.first(where: { $0.name == name }) else { fatalError("Missing target \(name)") }
    if target.fileSystemSynchronizedGroups?.isEmpty != false {
        let exclusions = name == "Sudokuly" ? ["Info.plist", "Sudokuly.entitlements"] : []
        let exceptions = PBXFileSystemSynchronizedBuildFileExceptionSet(target: target,
            membershipExceptions: exclusions, publicHeaders: nil, privateHeaders: nil,
            additionalCompilerFlagsByRelativePath: nil, attributesByRelativePath: nil)
        pbx.add(object: exceptions)
        let group = PBXFileSystemSynchronizedRootGroup(sourceTree: .group, path: folder, exceptions: [exceptions])
        pbx.add(object: group)
        if let old = main.children.first(where: { $0.name == name }) as? PBXGroup {
            main.children.removeAll { $0 == old }
            for reference in old.children { pbx.delete(object: reference) }
            pbx.delete(object: old)
        }
        main.children.append(group)
        target.fileSystemSynchronizedGroups = [group]
        for phase in target.buildPhases {
            if let sources = phase as? PBXSourcesBuildPhase {
                for file in sources.files ?? [] { pbx.delete(object: file) }
                sources.files = []
            }
            if let resources = phase as? PBXResourcesBuildPhase {
                for file in resources.files ?? [] { pbx.delete(object: file) }
                resources.files = []
            }
        }
    }
    for config in target.buildConfigurationList?.buildConfigurations ?? [] {
        config.buildSettings["DEVELOPMENT_TEAM"] = "5CPM5925FS"
        config.buildSettings["ONLY_ACTIVE_ARCH"] = config.name == "Debug" ? "YES" : "NO"
        if name == "Sudokuly" {
            config.buildSettings["CODE_SIGN_ENTITLEMENTS"] = "Sudokuly/Sudokuly.entitlements"
            config.buildSettings["OTHER_LDFLAGS"] = ["$(inherited)", "-ObjC"]
        }
    }
    if name == "Sudokuly" {
        var attributes = root.targetAttributes[target] ?? [:]
        attributes["DevelopmentTeam"] = "5CPM5925FS"
        var capabilities = attributes["SystemCapabilities"] as? [String: Any] ?? [:]
        capabilities["com.apple.SignInWithApple"] = ["enabled": 1]
        attributes["SystemCapabilities"] = capabilities
        root.setTargetAttributes(attributes, target: target)
    }
}
try project.write(path: projectPath)
print("Configured synchronized folders, signing team and Sign in with Apple. Existing package links preserved.")
