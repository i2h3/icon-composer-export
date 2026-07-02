/// The error type `IconComposerExport` throws for actool/iconutil failures and other problems discovered while compiling and extracting a rendered icon.
///
struct ExportError: Error, CustomStringConvertible {
    /// Human-readable explanation of what went wrong, surfaced by `ArgumentParser` when this error propagates out of `IconComposerExport.run()`.
    ///
    let message: String

    init(_ message: String) {
        self.message = message
    }

    /// This error's textual representation, required by `CustomStringConvertible`; returns `message` unchanged.
    ///
    var description: String {
        message
    }
}
