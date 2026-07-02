import ArgumentParser

/// Represents one of the appearances `IconComposerExport` can reliably render for an Icon Composer icon.
///
/// Icon Composer's icon.json format tags per-property overrides with an "appearance" value of
/// "dark" or "tinted" inside "<property>-specializations" arrays; entries with no "appearance"
/// key are the light/default value. This enum's raw values match that vocabulary exactly, and
/// are reused both as the `--appearance` command-line token and as the output filename suffix
/// in `IconComposerExport`. There is deliberately no `tinted` case: the system derives a tinted
/// (monochrome) render automatically for every layer, even ones without an explicit "tinted"
/// override, and `IconAppearanceResolver` can only reproduce overrides an icon actually authored;
/// see the README's "Limitations" section for why this makes a static tinted export unreliable.
///
enum Appearance: String, CaseIterable, ExpressibleByArgument {
    /// The default appearance, corresponding to specialization entries with no "appearance" key.
    case light

    /// The dark appearance, corresponding to specialization entries tagged "appearance": "dark".
    case dark
}
