@testable import IconComposerExport
import Testing

/// Verifies `IconAppearanceResolver`'s recursive promotion of "<property>-specializations" overrides,
/// using small in-memory fixtures that mirror the shapes found in real icon.json documents rather than
/// the checked-in `.icon` bundles, so these tests stay hermetic and fast.
///
struct IconAppearanceResolverTests {
    @Test
    func `promotes root level specialization for dark`() {
        let document: [String: Any] = [
            "fill": "light-value",
            "fill-specializations": [
                ["value": "light-value"],
                ["appearance": "dark", "value": "dark-value"],
            ],
        ]

        let (resolved, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)

        #expect(resolved["fill"] as? String == "dark-value")
        #expect(didApplyOverride)
    }

    @Test
    func `leaves default value when no matching override exists`() {
        // "tinted" is real Icon Composer vocabulary that can appear in an icon.json even though
        // Appearance has no .tinted case; resolving for .dark must ignore it, not crash on it.
        let document: [String: Any] = [
            "fill": "light-value",
            "fill-specializations": [
                ["value": "light-value"],
                ["appearance": "tinted", "value": "tinted-value"],
            ],
        ]

        let (resolved, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)

        #expect(resolved["fill"] as? String == "light-value")
        #expect(!didApplyOverride)
    }

    @Test
    func `promotes nested layer specialization`() {
        let document: [String: Any] = [
            "groups": [
                [
                    "layers": [
                        [
                            "name": "X",
                            "fill": "default",
                            "fill-specializations": [
                                ["value": "default"],
                                ["appearance": "dark", "value": "dark-fill"],
                            ],
                        ],
                    ],
                ],
            ],
        ]

        let (resolved, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)

        let groups = resolved["groups"] as? [[String: Any]]
        let layers = groups?.first?["layers"] as? [[String: Any]]
        let fill = layers?.first?["fill"] as? String

        #expect(fill == "dark-fill")
        #expect(didApplyOverride)
    }

    @Test
    func `promotes multiple sibling specializations independently`() {
        let layer: [String: Any] = [
            "name": "Cloud",
            "blend-mode": "screen",
            "blend-mode-specializations": [
                ["appearance": "dark", "value": "normal"],
            ],
            "fill": "default-fill",
            "fill-specializations": [
                ["value": "default-fill"],
                ["appearance": "dark", "value": "dark-fill"],
            ],
            "opacity": 0.5,
            "opacity-specializations": [
                ["appearance": "dark", "value": 0.9],
                ["appearance": "tinted", "value": 1],
            ],
        ]

        let document: [String: Any] = ["groups": [["layers": [layer]]]]

        // The layer also carries an irrelevant "tinted" opacity override (real Icon Composer icons
        // commonly do); resolving for .dark must pick the dark value (0.9), not the tinted one (1).
        let (darkResolved, darkDidApply) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)
        let darkLayer = ((darkResolved["groups"] as? [[String: Any]])?.first?["layers"] as? [[String: Any]])?.first

        #expect(darkLayer?["blend-mode"] as? String == "normal")
        #expect(darkLayer?["fill"] as? String == "dark-fill")
        #expect(darkLayer?["opacity"] as? Double == 0.9)
        #expect(darkDidApply)
    }

    @Test
    func `copies value types opaquely`() {
        let document: [String: Any] = [
            "solid": "extended-gray:1.0,1.0",
            "solid-specializations": [
                ["appearance": "dark", "value": "extended-gray:0.5,1.0"],
            ],
            "opacity": 0.5,
            "opacity-specializations": [
                ["appearance": "dark", "value": 0.9],
            ],
            "gradient": ["kind": "light"],
            "gradient-specializations": [
                ["appearance": "dark", "value": ["kind": "dark", "orientation": ["x": 0.5, "y": 0]]],
            ],
        ]

        let (resolved, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)

        #expect(resolved["solid"] as? String == "extended-gray:0.5,1.0")
        #expect(resolved["opacity"] as? Double == 0.9)

        let gradient = resolved["gradient"] as? [String: Any]
        #expect(gradient?["kind"] as? String == "dark")
        #expect((gradient?["orientation"] as? [String: Any])?["x"] as? Double == 0.5)
        #expect(didApplyOverride)
    }

    @Test
    func `is no op when document has no specializations`() {
        let document: [String: Any] = [
            "fill": "extended-gray:1.0,1.0",
            "groups": [
                [
                    "layers": [
                        ["name": "Pretzel", "fill": "extended-gray:1.0,1.0", "image-name": "Pretzel.svg"],
                    ],
                ],
            ],
            "supported-platforms": ["squares": ["macOS"]],
        ]

        let (resolved, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)

        #expect(!didApplyOverride)
        #expect(resolved["fill"] as? String == "extended-gray:1.0,1.0")

        let layer = ((resolved["groups"] as? [[String: Any]])?.first?["layers"] as? [[String: Any]])?.first
        #expect(layer?["fill"] as? String == "extended-gray:1.0,1.0")
    }

    @Test
    func `ignores malformed specializations value without crashing`() {
        let document: [String: Any] = [
            "foo": "default",
            "foo-specializations": "not an array",
        ]

        let (resolved, didApplyOverride) = IconAppearanceResolver.resolvedIconJSON(document, for: .dark)

        #expect(resolved["foo"] as? String == "default")
        #expect(!didApplyOverride)
    }
}
