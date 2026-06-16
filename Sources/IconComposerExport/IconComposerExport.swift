import ArgumentParser
import Foundation

@main
struct IconComposerExport: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "icon-composer-export", abstract: "Renders an Icon Composer (.icon) file as a full-size PNG into the same folder as the input.")

    @Argument(help: "Path to the Icon Composer (.icon) file to render.")
    var input: String

    mutating func run() throws {
        let fileManager = FileManager.default
        let inputURL = URL(fileURLWithPath: (input as NSString).expandingTildeInPath).standardizedFileURL

        guard inputURL.pathExtension.lowercased() == "icon" else {
            throw ValidationError("Input must have a .icon extension: \(inputURL.path)")
        }

        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: inputURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ValidationError("No Icon Composer file at: \(inputURL.path)")
        }

        let iconName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = inputURL.deletingLastPathComponent().appendingPathComponent("\(iconName).png")

        let workDir = fileManager.temporaryDirectory.appendingPathComponent("IconComposerExport-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: workDir)
        }

        let compileDir = workDir.appendingPathComponent("compiled", isDirectory: true)
        try fileManager.createDirectory(at: compileDir, withIntermediateDirectories: true)

        try Self.runProcess(
            "/usr/bin/xcrun",
            arguments: [
                "actool",
                "--compile", compileDir.path,
                "--platform", "macosx",
                "--minimum-deployment-target", "26.0",
                "--app-icon", iconName,
                "--standalone-icon-behavior", "all",
                "--output-partial-info-plist", workDir.appendingPathComponent("Info.plist").path,
                "--output-format", "human-readable-text",
                inputURL.path,
            ],
            failureMessage: "actool failed to compile the Icon Composer file"
        )

        let icnsURL = compileDir.appendingPathComponent("\(iconName).icns")

        guard fileManager.fileExists(atPath: icnsURL.path) else {
            throw ExportError("actool did not produce \(iconName).icns. The .icon file must support macOS or the square platforms.")
        }

        let iconsetURL = workDir.appendingPathComponent("\(iconName).iconset", isDirectory: true)

        try Self.runProcess(
            "/usr/bin/xcrun",
            arguments: ["iconutil", "--convert", "iconset", "--output", iconsetURL.path, icnsURL.path],
            failureMessage: "iconutil failed to extract the iconset"
        )

        let largestPNG = iconsetURL.appendingPathComponent("icon_512x512@2x.png")

        guard fileManager.fileExists(atPath: largestPNG.path) else {
            throw ExportError("The 1024x1024 PNG was not found in the iconset produced by iconutil.")
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        try fileManager.copyItem(at: largestPNG, to: outputURL)
        print(outputURL.path)
    }

    private static func runProcess(_ executable: String, arguments: [String], failureMessage: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ExportError("\(failureMessage): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }
}


