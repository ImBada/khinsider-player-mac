import Foundation

@main
struct UpdateBehaviorChecks {
    static func main() throws {
        try checkUpdateButtonUsesSparkleUpdater()
    }

    private static func checkUpdateButtonUsesSparkleUpdater() throws {
        let package = try sourceFile("Package.swift")
        let appUpdater = try sourceFile("Sources/KHPlayer/App/AppUpdater.swift")
        let appState = try sourceFile("Sources/KHPlayer/App/AppState.swift")
        let sidebarView = try sourceFile("Sources/KHPlayer/Features/Shell/SidebarView.swift")
        let packageScript = try sourceFile("Scripts/package_app.sh")
        let workflow = try sourceFile(".github/workflows/build-dmg.yml")

        precondition(package.contains("https://github.com/sparkle-project/Sparkle"))
        precondition(package.contains(".product(name: \"Sparkle\", package: \"Sparkle\")"))

        precondition(appUpdater.contains("import Sparkle"))
        precondition(appUpdater.contains("SPUStandardUpdaterController(startingUpdater: true"))
        precondition(appUpdater.contains("func checkForUpdates()"))

        precondition(appState.contains("internal let appUpdater: AppUpdater"))
        precondition(appState.contains("internal func checkForUpdates()"))

        precondition(!sidebarView.contains("@Environment(\\.openURL)"))
        precondition(!sidebarView.contains("openURL(updateAvailability.releaseURL)"))
        precondition(sidebarView.contains("appState.checkForUpdates()"))
        precondition(sidebarView.contains(".help(\"Check for and install app updates\")"))

        precondition(packageScript.contains("SUFeedURL"))
        precondition(packageScript.contains("SUPublicEDKey"))
        precondition(packageScript.contains("Contents/Frameworks"))
        precondition(packageScript.contains("Sparkle.framework"))

        precondition(workflow.contains("Create Sparkle update archive"))
        precondition(workflow.contains("Generate Sparkle appcast"))
        precondition(workflow.contains("Upload Sparkle update artifact"))
        precondition(workflow.contains("Generate GitHub release notes"))
        precondition(workflow.contains("repos/${GITHUB_REPOSITORY}/releases/generate-notes"))
        precondition(workflow.contains("--notes-file dist/release-notes.md"))
        precondition(workflow.contains("gh release edit \"$GITHUB_REF_NAME\" --notes-file dist/release-notes.md"))
        precondition(workflow.contains("releases/download/${GITHUB_REF_NAME}/"))
        precondition(workflow.contains("gh release upload \"$GITHUB_REF_NAME\" dist/*.dmg dist/sparkle-updates/*.zip --clobber"))
    }

    private static func sourceFile(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
