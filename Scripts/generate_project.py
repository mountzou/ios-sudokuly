#!/usr/bin/env python3
"""Regenerate the Xcode project using only Python's standard library."""
raise SystemExit("The project now uses synchronized folders and SDK dependencies. This legacy generator is disabled to preserve authentication settings. Use Scripts/XcodeSetup instead.")
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def uid(key):
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()

def quote(value):
    return json.dumps(str(value))

def add(key, body):
    identifier = uid(key)
    objects[identifier] = body
    return identifier

def refs(values):
    return "(" + ", ".join(values) + ",)" if values else "()"

def settings(values):
    return "{ " + " ".join(f"{key} = {quote(value)};" for key, value in values.items()) + " }"

def configs(name, base, release=None):
    identifiers = []
    for configuration in ("Debug", "Release"):
        values = dict(base)
        values["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if configuration == "Debug" else "-O"
        if configuration == "Debug":
            values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) DEBUG"
            values["ENABLE_TESTABILITY"] = "YES"
        if configuration == "Release" and release:
            values.update(release)
        identifiers.append(add(f"{name}-{configuration}", f"{{isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {configuration};}}"))
    return add(f"{name}-configs", f"{{isa = XCConfigurationList; buildConfigurations = {refs(identifiers)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}}")

groups = []
target_ids = []
products = []
app_id = uid("target-Sudokuly")
project_id = uid("project")

common = {
    "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Automatic", "CLANG_ENABLE_MODULES": "YES",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO", "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
}

for name, folder, product_type, extension in [
    ("Sudokuly", "Sudokuly", "com.apple.product-type.application", "app"),
    ("SudokulyTests", "Tests/SudokulyTests", "com.apple.product-type.bundle.unit-test", "xctest"),
    ("SudokulyUITests", "Tests/SudokulyUITests", "com.apple.product-type.bundle.ui-testing", "xctest"),
]:
    children, sources, resources = [], [], []
    paths = sorted((ROOT / folder).rglob("*.swift"))
    if name == "Sudokuly":
        paths += [ROOT / "Sudokuly/Info.plist", ROOT / "Sudokuly/Resources/Assets.xcassets",
                  ROOT / "Sudokuly/Resources/Fonts/ClarityCity-Variable.ttf", ROOT / "Sudokuly/Resources/Fonts/OFL.txt",
                  ROOT / "Sudokuly/Resources/PrivacyInfo.xcprivacy"]
    for path in paths:
        relative = str(path.relative_to(ROOT))
        file_type = {".swift": "sourcecode.swift", ".plist": "text.plist.xml", ".xcassets": "folder.assetcatalog",
                     ".ttf": "file", ".txt": "text", ".xcprivacy": "text.xml"}[path.suffix]
        ref = add("file-" + relative, f"{{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {quote(relative)}; sourceTree = SOURCE_ROOT;}}")
        children.append(ref)
        if path.name == "Info.plist":
            continue
        build = add("build-" + relative, f"{{isa = PBXBuildFile; fileRef = {ref};}}")
        (sources if path.suffix == ".swift" else resources).append(build)
    groups.append(add("group-" + name, f"{{isa = PBXGroup; children = {refs(children)}; name = {name}; sourceTree = \"<group>\";}}"))
    phases = []
    for label, isa, files in [("sources", "PBXSourcesBuildPhase", sources), ("frameworks", "PBXFrameworksBuildPhase", []), ("resources", "PBXResourcesBuildPhase", resources)]:
        phases.append(add(name + "-" + label, f"{{isa = {isa}; buildActionMask = 2147483647; files = {refs(files)}; runOnlyForDeploymentPostprocessing = 0;}}"))
    product_name = "sudokuly" if name == "Sudokuly" else name
    product = add("product-" + name, f"{{isa = PBXFileReference; explicitFileType = {'wrapper.application' if extension == 'app' else 'wrapper.cfbundle'}; includeInIndex = 0; path = {product_name}.{extension}; sourceTree = BUILT_PRODUCTS_DIR;}}")
    products.append(product)
    values = dict(common, PRODUCT_NAME=product_name, PRODUCT_BUNDLE_IDENTIFIER="gr.mountzou." + product_name,
                  GENERATE_INFOPLIST_FILE="YES", LD_RUNPATH_SEARCH_PATHS="$(inherited) @executable_path/Frameworks @loader_path/Frameworks")
    dependencies = []
    if name == "Sudokuly":
        values.update({"GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": "Sudokuly/Info.plist", "PRODUCT_MODULE_NAME": "Sudokuly",
                       "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "MARKETING_VERSION": "1.0.0", "CURRENT_PROJECT_VERSION": "1"})
    else:
        proxy = add(name + "-proxy", f"{{isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_id}; remoteInfo = Sudokuly;}}")
        dependencies.append(add(name + "-dependency", f"{{isa = PBXTargetDependency; target = {app_id}; targetProxy = {proxy};}}"))
        if name == "SudokulyTests":
            values.update(TEST_HOST="$(BUILT_PRODUCTS_DIR)/sudokuly.app/sudokuly", BUNDLE_LOADER="$(TEST_HOST)")
        else:
            values.update(TEST_TARGET_NAME="Sudokuly")
    configuration_list = configs(name, values)
    target_ids.append(add("target-" + name, f"{{isa = PBXNativeTarget; buildConfigurationList = {configuration_list}; buildPhases = {refs(phases)}; buildRules = (); dependencies = {refs(dependencies)}; name = {name}; productName = {product_name}; productReference = {product}; productType = {quote(product_type)};}}"))

product_group = add("products", f"{{isa = PBXGroup; children = {refs(products)}; name = Products; sourceTree = \"<group>\";}}")
main_group = add("main", f"{{isa = PBXGroup; children = {refs(groups + [product_group])}; sourceTree = \"<group>\";}}")
project_config = configs("project", {"CLANG_ENABLE_OBJC_ARC": "YES", "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES", "GCC_WARN_UNUSED_VARIABLE": "YES", "SWIFT_STRICT_CONCURRENCY": "complete"})
add("project", f"{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;}}; buildConfigurationList = {project_config}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {product_group}; projectDirPath = \"\"; projectRoot = \"\"; targets = {refs(target_ids)};}}")

project = ROOT / "sudokuly.xcodeproj"
project.mkdir(exist_ok=True)
content = "// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n"
content += "\n".join(f"\t{key} = {body};" for key, body in objects.items())
content += f"\n}}; rootObject = {project_id}; }}\n"
(project / "project.pbxproj").write_text(content)

def buildable(name):
    product = "sudokuly.app" if name == "Sudokuly" else name + ".xctest"
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target-" + name)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:sudokuly.xcodeproj"/>'

scheme = project / "xcshareddata/xcschemes"
scheme.mkdir(parents=True, exist_ok=True)
(scheme / "Sudokuly.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable("Sudokuly")}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO">{buildable("SudokulyTests")}</TestableReference><TestableReference skipped="NO">{buildable("SudokulyUITests")}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable("Sudokuly")}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable("Sudokuly")}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("Generated sudokuly.xcodeproj with app, unit tests and UI tests.")
