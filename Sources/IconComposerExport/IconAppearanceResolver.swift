/// Rewrites a parsed icon.json document so that its default values represent a specific appearance.
///
/// actool only ever rasterizes the non-"-specializations" ("default") value of any property in an
/// icon.json document; it never bakes "dark" or "tinted" specialization overrides into a static
/// bitmap. `IconComposerExport` works around this by using `IconAppearanceResolver` to promote a
/// target appearance's override values into their sibling default keys in a temporary copy of the
/// bundle before compiling it, so that actool's existing default-only rendering path produces that
/// appearance instead.
///
enum IconAppearanceResolver {
    /// Returns `document` with every "<property>-specializations" entry matching `appearance` promoted into its sibling "<property>" key.
    ///
    /// The second element of the returned tuple is `true` if at least one override was promoted anywhere in the
    /// document, which callers can use to warn when a bundle defines no overrides at all for the requested appearance
    /// and the result is therefore identical to the light rendering. Properties without a matching override are left
    /// completely unchanged, falling back to their light/default value; this is a known fidelity limitation compared
    /// to the OS's live "automatic" derivation of unspecified appearance colors, which this tool cannot replicate.
    ///
    static func resolvedIconJSON(_ document: [String: Any], for appearance: Appearance) -> (json: [String: Any], didApplyOverride: Bool) {
        var didApplyOverride = false
        let resolved = promoting(document, for: appearance, didApplyOverride: &didApplyOverride)
        return (resolved as? [String: Any] ?? document, didApplyOverride)
    }

    /// Recursively walks a JSON node produced by `JSONSerialization`, promoting matching specialization overrides wherever they occur.
    ///
    /// Dictionaries are recursed into and then scanned for "<property>-specializations" keys at that level; arrays are
    /// recursed into element-by-element, which is how this reaches every layer inside every group; every other value is
    /// a JSON leaf (string, number, boolean, or null) and is returned unchanged. A specialization entry's "value" is
    /// always copied opaquely, regardless of whether it is a leaf or a nested object, since this function never
    /// interprets what a value means.
    ///
    private static func promoting(_ node: Any, for appearance: Appearance, didApplyOverride: inout Bool) -> Any {
        if let array = node as? [Any] {
            return array.map { promoting($0, for: appearance, didApplyOverride: &didApplyOverride) }
        }

        guard let dictionary = node as? [String: Any] else {
            return node
        }

        var transformed: [String: Any] = [:]

        for (key, value) in dictionary {
            transformed[key] = promoting(value, for: appearance, didApplyOverride: &didApplyOverride)
        }

        for key in transformed.keys where key.hasSuffix("-specializations") {
            guard let entries = transformed[key] as? [[String: Any]] else {
                continue
            }

            guard let match = entries.first(where: { ($0["appearance"] as? String) == appearance.rawValue }) else {
                continue
            }

            let baseKey = String(key.dropLast("-specializations".count))
            transformed[baseKey] = match["value"]
            didApplyOverride = true
        }

        return transformed
    }
}
