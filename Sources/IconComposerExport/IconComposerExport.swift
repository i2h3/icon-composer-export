import ArgumentParser
import Foundation

/// Command line tool that renders an Icon Composer (.icon) bundle as one or more full-size PNGs, one per requested appearance.
///
/// This is a thin wrapper around Apple's `actool` and `iconutil` command line tools, which do all
/// of the actual compiling and rasterizing; this type only orchestrates them and, for non-light
/// appearances, pre-processes the input bundle's icon.json via `IconAppearanceResolver` beforehand.
///
@main
struct IconComposerExport: ParsableCommand {
    /// Configures this command's name and abstract, as required by `ParsableCommand`.
    ///
    static let configuration = CommandConfiguration(commandName: "icon-composer-export", abstract: "Renders an Icon Composer (.icon) file as a full-size PNG (light and/or dark) into the same folder as the input.")

    /// Path to the Icon Composer (.icon) bundle to render.
    ///
    @Argument(help: "Path to the Icon Composer (.icon) file to render.")
    var input: String

    /// Which appearance of the icon to render; if `nil`, every appearance in `Appearance.allCases` is rendered.
    ///
    /// See `Appearance` for why tinted (monochrome) rendering is not offered here.
    ///
    @Option(help: "Which appearance to render: light or dark. If omitted, both are rendered.")
    var appearance: Appearance?

    /// Directory the rendered PNG(s) are written into, defaulting to `input`'s own directory.
    ///
    @Argument(help: "Directory to write the rendered PNG(s) into. Defaults to the input file's directory.")
    var output: String?

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
        let outputDirectoryURL = try Self.outputDirectoryURL(for: inputURL, explicitOutput: output, fileManager: fileManager)
        let appearancesToRender = appearance.map { [$0] } ?? Appearance.allCases

        for appearanceToRender in appearancesToRender {
            let outputURL = try Self.export(appearanceToRender, of: inputURL, iconName: iconName, to: outputDirectoryURL, fileManager: fileManager)
            print(outputURL.path)
        }
    }

    /// Compiles `inputURL` for `appearance` and copies the resulting PNG into `outputDirectoryURL`, returning its URL.
    ///
    /// This does all the actool/iconutil orchestration for a single appearance; `run()` calls it once per
    /// appearance in `appearancesToRender`, since omitting `--appearance` renders every case in `Appearance.allCases`.
    ///
    private static func export(_ appearance: Appearance, of inputURL: URL, iconName: String, to outputDirectoryURL: URL, fileManager: FileManager) throws -> URL {
        let outputURL = outputDirectoryURL.appendingPathComponent("\(iconName)-\(appearance.rawValue).png")

        let workDir = fileManager.temporaryDirectory.appendingPathComponent("IconComposerExport-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: workDir)
        }

        let compileSourceURL = try Self.compileSourceURL(for: inputURL, iconName: iconName, appearance: appearance, workDir: workDir, fileManager: fileManager)

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
                compileSourceURL.path,
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

        return outputURL
    }

    /// Returns the URL that should be passed to `actool`, promoting `appearance`'s overrides into the default values of a temporary copy of `inputURL` when it is not `.light`.
    ///
    /// For `.light` this returns `inputURL` unchanged, since actool already rasterizes the light/default
    /// appearance directly and no rewriting is needed. For `.dark`, this copies the whole bundle under
    /// `workDir` and rewrites its icon.json via `IconAppearanceResolver` before returning the copy's URL,
    /// leaving the original `inputURL` untouched.
    ///
    private static func compileSourceURL(for inputURL: URL, iconName: String, appearance: Appearance, workDir: URL, fileManager: FileManager) throws -> URL {
        guard appearance != .light else {
            return inputURL
        }

        let synthesizedIconURL = workDir.appendingPathComponent("\(iconName).icon", isDirectory: true)
        try fileManager.copyItem(at: inputURL, to: synthesizedIconURL)

        let iconJSONURL = synthesizedIconURL.appendingPathComponent("icon.json")
        let originalData = try Data(contentsOf: iconJSONURL)

        guard let originalJSON = try JSONSerialization.jsonObject(with: originalData) as? [String: Any] else {
            throw ExportError("icon.json at \(iconJSONURL.path) does not contain a valid JSON object.")
        }

        let (resolvedJSON, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(originalJSON, for: appearance)

        if !didApplyOverride {
            FileHandle.standardError.write(Data("warning: icon.json has no \(appearance.rawValue) overrides; output will be identical to light\n".utf8))
        }

        let resolvedData = try JSONSerialization.data(withJSONObject: resolvedJSON, options: [.sortedKeys])
        try resolvedData.write(to: iconJSONURL)

        return synthesizedIconURL
    }

    /// Returns the directory the rendered PNG(s) should be written into, creating it if it does not already exist.
    ///
    /// When `explicitOutput` is `nil` this returns `inputURL`'s own directory, matching the tool's original
    /// behavior. When it is provided, it is resolved relative to the current working directory (mirroring how
    /// `input` itself is resolved) and must not already exist as a non-directory file.
    ///
    private static func outputDirectoryURL(for inputURL: URL, explicitOutput: String?, fileManager: FileManager) throws -> URL {
        guard let explicitOutput else {
            return inputURL.deletingLastPathComponent()
        }

        let outputURL = URL(fileURLWithPath: (explicitOutput as NSString).expandingTildeInPath).standardizedFileURL

        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: outputURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            throw ValidationError("Output path is not a directory: \(outputURL.path)")
        }

        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

        return outputURL
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
