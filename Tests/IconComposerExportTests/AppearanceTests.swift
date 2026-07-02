@testable import IconComposerExport
import Testing

/// Verifies `Appearance`'s raw values and `ArgumentParser` round-trip, since those are the public
/// contract of the `--appearance` command line option and the output filename suffix in `IconComposerExport`.
///
struct AppearanceTests {
    @Test
    func `has exactly two cases`() {
        #expect(Appearance.allCases.count == 2)
    }

    @Test(arguments: [(Appearance.light, "light"), (Appearance.dark, "dark")])
    func `raw value matches expected token`(appearance: Appearance, token: String) {
        #expect(appearance.rawValue == token)
    }

    @Test(arguments: Appearance.allCases)
    func `round trips through argument parser`(appearance: Appearance) {
        #expect(Appearance(argument: appearance.rawValue) == appearance)
    }
}
